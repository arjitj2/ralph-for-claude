#!/bin/bash
# Ralph for Claude Code - Autonomous AI agent loop
# Adapted from https://github.com/snarktank/ralph
#
# Usage: ./ralph.sh [max_iterations]
#
# Before first run, set up your PRD:
#   ./setup.sh ../tasks/prd-your-feature.json

set -e

MAX_ITERATIONS=${1:-10}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# Function to format duration
format_duration() {
  local seconds=$1
  local minutes=$((seconds / 60))
  local remaining_seconds=$((seconds % 60))
  if [ $minutes -gt 0 ]; then
    echo "${minutes}m ${remaining_seconds}s"
  else
    echo "${seconds}s"
  fi
}

# Function to run heartbeat in background
# Prints a dot every minute to show the process is alive
start_heartbeat() {
  local task_id=$1
  (
    local elapsed=0
    while true; do
      sleep 60
      elapsed=$((elapsed + 1))
      echo -e "${GRAY}  ♥ [$task_id] Still running... (${elapsed}m elapsed)${NC}"
    done
  ) &
  HEARTBEAT_PID=$!
}

stop_heartbeat() {
  if [ -n "$HEARTBEAT_PID" ]; then
    kill $HEARTBEAT_PID 2>/dev/null || true
    wait $HEARTBEAT_PID 2>/dev/null || true
    unset HEARTBEAT_PID
  fi
}

# Cleanup heartbeat on script exit
trap stop_heartbeat EXIT

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Ralph for Claude Code                         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if PRD file exists
if [ ! -f "$PRD_FILE" ]; then
  echo -e "${RED}Error: No prd.json found in ralph/${NC}"
  echo ""
  echo "Run setup.sh first to configure a PRD:"
  echo "  ./setup.sh ../tasks/prd-your-feature.json"
  echo ""
  echo "Available PRDs in tasks/:"
  ls -1 "$SCRIPT_DIR/../tasks/"*.json 2>/dev/null | while read f; do
    echo "  - $(basename "$f")"
  done
  exit 1
fi

# Check if prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
  echo -e "${RED}Error: prompt.md not found${NC}"
  exit 1
fi

# Check if progress file exists
if [ ! -f "$PROGRESS_FILE" ]; then
  echo -e "${YELLOW}Warning: progress.txt not found, creating default${NC}"
  cp "$SCRIPT_DIR/progress.txt.template" "$PROGRESS_FILE" 2>/dev/null || \
    echo "# Ralph Progress Log" > "$PROGRESS_FILE"
fi

# Display config
FEATURE=$(jq -r '.branchName // .featureName // "unknown"' "$PRD_FILE")
echo -e "Feature: ${GREEN}$FEATURE${NC}"
echo -e "Max Iterations: ${YELLOW}$MAX_ITERATIONS${NC}"
echo ""

# Function to count completed and total tasks
count_tasks() {
  TOTAL=$(jq '.tasks | length' "$PRD_FILE")
  COMPLETED=$(jq '[.tasks[] | select(.passes == true)] | length' "$PRD_FILE")
  echo "$COMPLETED/$TOTAL"
}

# Function to check if all tasks are complete
all_complete() {
  jq -e '.tasks | all(.passes == true)' "$PRD_FILE" > /dev/null 2>&1
}

# Function to get next task
get_next_task() {
  jq -r '
    .tasks as $tasks |
    .tasks[] |
    select(.passes == false) |
    select(
      (.dependsOn // []) | all(. as $dep | $tasks[] | select(.id == $dep) | .passes == true)
    ) |
    .id
  ' "$PRD_FILE" | head -1
}

# Check initial status
INITIAL_STATUS=$(count_tasks)
echo -e "Task status: ${GREEN}$INITIAL_STATUS${NC} complete"

# Check if already complete
if all_complete; then
  echo ""
  echo -e "${GREEN}All tasks already complete!${NC}"
  exit 0
fi

# Show next task
NEXT_TASK_ID=$(get_next_task)
if [ -z "$NEXT_TASK_ID" ]; then
  echo ""
  echo -e "${RED}No eligible tasks found (check dependencies)${NC}"
  exit 1
fi

NEXT_TASK_TITLE=$(jq -r --arg id "$NEXT_TASK_ID" '.tasks[] | select(.id == $id) | .title' "$PRD_FILE")
echo -e "Next task: ${YELLOW}$NEXT_TASK_TITLE${NC}"
echo ""

# Track total time
TOTAL_START_TIME=$(date +%s)

# Main iteration loop
for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Iteration $i of $MAX_ITERATIONS │ $(count_tasks) complete${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

  # Get next eligible task
  NEXT_TASK_ID=$(get_next_task)
  if [ -z "$NEXT_TASK_ID" ]; then
    if all_complete; then
      echo -e "${GREEN}All tasks complete!${NC}"
      exit 0
    else
      echo -e "${RED}No eligible tasks (blocked by dependencies)${NC}"
      exit 1
    fi
  fi

  NEXT_TASK_TITLE=$(jq -r --arg id "$NEXT_TASK_ID" '.tasks[] | select(.id == $id) | .title' "$PRD_FILE")
  echo ""
  echo -e "Task: ${YELLOW}[$NEXT_TASK_ID]${NC} $NEXT_TASK_TITLE"
  echo ""

  # Build the prompt with file paths
  FULL_PROMPT="$(cat "$PROMPT_FILE")

---
PRD_FILE_PATH: $PRD_FILE
PROGRESS_FILE_PATH: $PROGRESS_FILE
PROJECT_ROOT: $SCRIPT_DIR/.."

  # Run Claude Code with timing and heartbeat
  echo -e "${YELLOW}Starting Claude Code session...${NC}"
  echo ""

  ITERATION_START_TIME=$(date +%s)
  OUTPUT_FILE=$(mktemp)

  # Start heartbeat
  start_heartbeat "$NEXT_TASK_ID"

  if claude --dangerously-skip-permissions -p "$FULL_PROMPT" 2>&1 | tee "$OUTPUT_FILE"; then
    echo ""
    echo -e "${GREEN}Session completed${NC}"
  else
    echo ""
    echo -e "${YELLOW}Session exited${NC}"
  fi

  # Stop heartbeat
  stop_heartbeat

  # Calculate duration
  ITERATION_END_TIME=$(date +%s)
  ITERATION_DURATION=$((ITERATION_END_TIME - ITERATION_START_TIME))
  FORMATTED_DURATION=$(format_duration $ITERATION_DURATION)

  echo -e "${GRAY}  Duration: ${FORMATTED_DURATION}${NC}"

  # Check for completion signal
  if grep -q "<promise>COMPLETE</promise>" "$OUTPUT_FILE" 2>/dev/null; then
    TOTAL_END_TIME=$(date +%s)
    TOTAL_DURATION=$((TOTAL_END_TIME - TOTAL_START_TIME))
    TOTAL_FORMATTED=$(format_duration $TOTAL_DURATION)

    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  All tasks complete! (iteration $i)                   ║${NC}"
    echo -e "${GREEN}║  Total time: $TOTAL_FORMATTED                              ${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
    rm -f "$OUTPUT_FILE"
    exit 0
  fi

  rm -f "$OUTPUT_FILE"

  # Check completion via prd.json
  if all_complete; then
    TOTAL_END_TIME=$(date +%s)
    TOTAL_DURATION=$((TOTAL_END_TIME - TOTAL_START_TIME))
    TOTAL_FORMATTED=$(format_duration $TOTAL_DURATION)

    echo ""
    echo -e "${GREEN}All tasks complete (via prd.json check)!${NC}"
    echo -e "${GREEN}Total time: $TOTAL_FORMATTED${NC}"
    exit 0
  fi

  # Status update
  echo ""
  echo -e "After iteration $i: ${GREEN}$(count_tasks)${NC} complete (took ${FORMATTED_DURATION})"

  # Pause before next iteration
  if [ $i -lt $MAX_ITERATIONS ]; then
    echo -e "${YELLOW}Next iteration in 3s...${NC}"
    sleep 3
  fi
done

TOTAL_END_TIME=$(date +%s)
TOTAL_DURATION=$((TOTAL_END_TIME - TOTAL_START_TIME))
TOTAL_FORMATTED=$(format_duration $TOTAL_DURATION)

echo ""
echo -e "${RED}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  Reached max iterations ($MAX_ITERATIONS)                        ║${NC}"
echo -e "${RED}║  Total time: $TOTAL_FORMATTED                              ${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Final: ${YELLOW}$(count_tasks)${NC} complete"
echo "Check progress.txt for details"
exit 1
