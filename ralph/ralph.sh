#!/bin/bash
# Ralph for Claude Code - Autonomous AI agent loop
# Adapted from https://github.com/snarktank/ralph
#
# Usage: ./ralph.sh <prd-filepath> [max_iterations]
# Example: ./ralph.sh tasks/prd-ui-polish.json 10
#
# Features:
#   - Creates archive folder immediately (no separate setup step)
#   - Auto-resumes incomplete runs when same PRD is passed again
#   - Preserves original PRD filename in archive

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVE_DIR="$SCRIPT_DIR/archive"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
CONFIG_FILE="$SCRIPT_DIR/ralph.config"
TEMPLATE_FILE="$SCRIPT_DIR/progress.txt.template"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
GRAY='\033[0;90m'
NC='\033[0m' # No Color

# ═══════════════════════════════════════════════════════════════════════════════
# HELPER FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

print_usage() {
  echo "Usage: ./ralph.sh <prd-filepath> [max_iterations]"
  echo ""
  echo "Examples:"
  echo "  ./ralph.sh tasks/prd-ui-polish.json       # 10 iterations (default)"
  echo "  ./ralph.sh tasks/prd-ui-polish.json 20    # 20 iterations"
  echo ""
  echo "The script will:"
  echo "  - Create an archive folder for the run"
  echo "  - Auto-resume if an incomplete run exists for this feature"
}

list_available_prds() {
  echo "Available PRDs:"
  local found=0
  for dir in "$SCRIPT_DIR/../tasks" "./tasks" "."; do
    if [ -d "$dir" ] && ls "$dir"/*.json 2>/dev/null | head -1 >/dev/null; then
      ls -1 "$dir"/*.json 2>/dev/null | while read f; do
        echo "  - $f"
      done
      found=1
    fi
  done
  if [ $found -eq 0 ]; then
    echo "  (none found)"
  fi
}

# Extract feature name from PRD JSON
extract_feature_name() {
  local prd_path="$1"
  jq -r '.branchName // .featureName // "unknown"' "$prd_path"
}

# Sanitize feature name for folder naming
sanitize_for_folder() {
  local name="$1"
  echo "$name" | sed 's|^feature/||' | sed 's|/|-|g' | sed 's|[^a-zA-Z0-9_-]|-|g'
}

# Validate PRD file
validate_prd_file() {
  local prd_path="$1"

  # Handle .md files - suggest conversion
  if [[ "$prd_path" == *.md ]]; then
    local json_file="${prd_path%.md}.json"
    if [ -f "$json_file" ]; then
      echo -e "${YELLOW}Note: Using corresponding .json file${NC}"
      echo -e "  ${BLUE}$prd_path${NC} -> ${GREEN}$json_file${NC}"
      echo "$json_file"
      return 0
    else
      echo -e "${RED}Error: Pass a .json file, not .md${NC}"
      echo ""
      echo "Run /convert-prd-to-json first:"
      echo -e "  ${BLUE}/convert-prd-to-json $prd_path${NC}"
      exit 1
    fi
  fi

  # Check file exists
  if [ ! -f "$prd_path" ]; then
    echo -e "${RED}Error: PRD file not found: $prd_path${NC}"
    echo ""
    list_available_prds
    exit 1
  fi

  # Validate JSON syntax
  if ! jq empty "$prd_path" 2>/dev/null; then
    echo -e "${RED}Error: Invalid JSON in: $prd_path${NC}"
    echo ""
    jq empty "$prd_path" 2>&1 | head -5
    exit 1
  fi

  # Validate required fields
  if ! jq -e '.tasks' "$prd_path" >/dev/null 2>&1; then
    echo -e "${RED}Error: PRD missing 'tasks' array${NC}"
    exit 1
  fi

  echo "$prd_path"
}

# Find incomplete run for given feature in archive
find_incomplete_run() {
  local folder_feature="$1"

  # List folders matching pattern, most recent first (by timestamp prefix)
  for folder in $(ls -dt "$ARCHIVE_DIR"/*-"$folder_feature" 2>/dev/null); do
    if [ -d "$folder" ]; then
      local prd=$(find "$folder" -maxdepth 1 -name "*.json" -type f 2>/dev/null | head -1)
      if [ -n "$prd" ] && [ -f "$prd" ]; then
        # Check if any task is incomplete
        local incomplete=$(jq -e '.tasks[] | select(.passes == false)' "$prd" 2>/dev/null | head -1)
        if [ -n "$incomplete" ]; then
          echo "$folder"
          return 0
        fi
      fi
    fi
  done
  return 1
}

# Initialize progress.txt from template
initialize_progress_file() {
  local progress_path="$1"
  local feature_name="$2"

  if [ -f "$TEMPLATE_FILE" ]; then
    cp "$TEMPLATE_FILE" "$progress_path"
  else
    cat > "$progress_path" << 'EOF'
# Ralph Progress Log
Feature: (will be updated)
Started: (will be updated)

## Codebase Patterns

(Patterns discovered during implementation will be added here)

---

EOF
  fi

  # Update with feature info (macOS sed syntax)
  sed -i '' "s|Feature: .*|Feature: $feature_name|" "$progress_path" 2>/dev/null || \
    sed -i "s|Feature: .*|Feature: $feature_name|" "$progress_path"
  sed -i '' "s|Started: .*|Started: $(date)|" "$progress_path" 2>/dev/null || \
    sed -i "s|Started: .*|Started: $(date)|" "$progress_path"
}

# Format duration nicely
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

# Heartbeat - shows process is alive
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

# Load project config
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
  else
    echo -e "${YELLOW}Warning: ralph.config not found. Using default test command.${NC}"
    TEST_COMMAND="echo 'No test command configured'"
  fi
}

# Task counting functions
count_tasks() {
  local prd="$1"
  local total=$(jq '.tasks | length' "$prd")
  local completed=$(jq '[.tasks[] | select(.passes == true)] | length' "$prd")
  echo "$completed/$total"
}

all_complete() {
  local prd="$1"
  jq -e '.tasks | all(.passes == true)' "$prd" > /dev/null 2>&1
}

get_next_task() {
  local prd="$1"
  jq -r '
    .tasks as $tasks |
    .tasks[] |
    select(.passes == false) |
    select(
      (.dependsOn // []) | all(. as $dep | $tasks[] | select(.id == $dep) | .passes == true)
    ) |
    .id
  ' "$prd" | head -1
}

# Check if a specific task is complete
task_is_complete() {
  local prd="$1"
  local task_id="$2"
  jq -e --arg id "$task_id" '.tasks[] | select(.id == $id) | .passes == true' "$prd" > /dev/null 2>&1
}

# Cleanup on exit
cleanup_and_exit() {
  stop_heartbeat
  echo ""
  echo -e "${YELLOW}Interrupted. Progress saved to:${NC}"
  echo "  PRD: $ACTIVE_PRD_PATH"
  echo "  Log: $ACTIVE_PROGRESS_PATH"
  echo ""
  echo "Resume with: ./ralph.sh $PRD_INPUT_PATH"
  exit 130
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN SCRIPT
# ═══════════════════════════════════════════════════════════════════════════════

# Parse arguments
PRD_INPUT_PATH="$1"
MAX_ITERATIONS=${2:-10}

# Check for help
if [ "$PRD_INPUT_PATH" = "-h" ] || [ "$PRD_INPUT_PATH" = "--help" ]; then
  print_usage
  exit 0
fi

# Require PRD argument
if [ -z "$PRD_INPUT_PATH" ]; then
  echo -e "${RED}Error: No PRD file specified${NC}"
  echo ""
  print_usage
  echo ""
  list_available_prds
  exit 1
fi

# Load config
load_config

# Validate PRD and potentially convert .md path to .json
PRD_INPUT_PATH=$(validate_prd_file "$PRD_INPUT_PATH")

# Extract feature name
FEATURE_NAME=$(extract_feature_name "$PRD_INPUT_PATH")
FOLDER_FEATURE=$(sanitize_for_folder "$FEATURE_NAME")

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Ralph for Claude Code                         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Ensure archive directory exists
mkdir -p "$ARCHIVE_DIR"

# Check for incomplete run to resume
INCOMPLETE_RUN_FOLDER=$(find_incomplete_run "$FOLDER_FEATURE" || echo "")

if [ -n "$INCOMPLETE_RUN_FOLDER" ]; then
  # RESUME MODE
  ACTIVE_FOLDER="$INCOMPLETE_RUN_FOLDER"
  ACTIVE_PRD_PATH=$(find "$ACTIVE_FOLDER" -maxdepth 1 -name "*.json" -type f | head -1)
  ACTIVE_PROGRESS_PATH="$ACTIVE_FOLDER/progress.txt"

  COMPLETED=$(jq '[.tasks[] | select(.passes == true)] | length' "$ACTIVE_PRD_PATH")
  TOTAL=$(jq '.tasks | length' "$ACTIVE_PRD_PATH")

  echo -e "${YELLOW}Resuming incomplete run: $FEATURE_NAME ($COMPLETED/$TOTAL complete)${NC}"
  echo -e "Archive: ${BLUE}$ACTIVE_FOLDER${NC}"
else
  # NEW RUN MODE
  TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
  ACTIVE_FOLDER="$ARCHIVE_DIR/$TIMESTAMP-$FOLDER_FEATURE"
  mkdir -p "$ACTIVE_FOLDER"

  # Copy PRD preserving original filename
  ORIGINAL_FILENAME=$(basename "$PRD_INPUT_PATH")
  ACTIVE_PRD_PATH="$ACTIVE_FOLDER/$ORIGINAL_FILENAME"
  cp "$PRD_INPUT_PATH" "$ACTIVE_PRD_PATH"

  # Initialize progress.txt
  ACTIVE_PROGRESS_PATH="$ACTIVE_FOLDER/progress.txt"
  initialize_progress_file "$ACTIVE_PROGRESS_PATH" "$FEATURE_NAME"

  echo -e "${GREEN}Starting new run: $FEATURE_NAME${NC}"
  echo -e "Archive: ${BLUE}$ACTIVE_FOLDER${NC}"

  # Show task summary
  echo ""
  echo -e "${BLUE}Tasks:${NC}"
  jq -r '.tasks[] | "  [\(if .passes then "x" else " " end)] \(.id): \(.title)"' "$ACTIVE_PRD_PATH"
fi

echo ""

# Set up trap for graceful exit
trap cleanup_and_exit SIGINT SIGTERM

# Check if prompt file exists
if [ ! -f "$PROMPT_FILE" ]; then
  echo -e "${RED}Error: prompt.md not found${NC}"
  exit 1
fi

# Display config
echo -e "Feature: ${GREEN}$FEATURE_NAME${NC}"
echo -e "Max Iterations: ${YELLOW}$MAX_ITERATIONS${NC}"
echo ""

# Check initial status
INITIAL_STATUS=$(count_tasks "$ACTIVE_PRD_PATH")
echo -e "Task status: ${GREEN}$INITIAL_STATUS${NC} complete"

# Check if already complete
if all_complete "$ACTIVE_PRD_PATH"; then
  echo ""
  echo -e "${GREEN}All tasks already complete!${NC}"
  exit 0
fi

# Show next task
NEXT_TASK_ID=$(get_next_task "$ACTIVE_PRD_PATH")
if [ -z "$NEXT_TASK_ID" ]; then
  echo ""
  echo -e "${RED}No eligible tasks found (check dependencies)${NC}"
  exit 1
fi

NEXT_TASK_TITLE=$(jq -r --arg id "$NEXT_TASK_ID" '.tasks[] | select(.id == $id) | .title' "$ACTIVE_PRD_PATH")
echo -e "Next task: ${YELLOW}$NEXT_TASK_TITLE${NC}"
echo ""

# Track total time
TOTAL_START_TIME=$(date +%s)

# Main iteration loop
for i in $(seq 1 $MAX_ITERATIONS); do
  echo ""
  echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
  echo -e "${BLUE}  Iteration $i of $MAX_ITERATIONS │ $(count_tasks "$ACTIVE_PRD_PATH") complete${NC}"
  echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"

  # Get next eligible task
  NEXT_TASK_ID=$(get_next_task "$ACTIVE_PRD_PATH")
  if [ -z "$NEXT_TASK_ID" ]; then
    if all_complete "$ACTIVE_PRD_PATH"; then
      echo -e "${GREEN}All tasks complete!${NC}"
      exit 0
    else
      echo -e "${RED}No eligible tasks (blocked by dependencies)${NC}"
      exit 1
    fi
  fi

  NEXT_TASK_TITLE=$(jq -r --arg id "$NEXT_TASK_ID" '.tasks[] | select(.id == $id) | .title' "$ACTIVE_PRD_PATH")
  echo ""
  echo -e "Task: ${YELLOW}[$NEXT_TASK_ID]${NC} $NEXT_TASK_TITLE"
  echo ""

  # Build the prompt with file paths and substitute TEST_COMMAND
  PROMPT_CONTENT="$(cat "$PROMPT_FILE" | sed "s|{{TEST_COMMAND}}|$TEST_COMMAND|g")"
  FULL_PROMPT="$PROMPT_CONTENT

---
PRD_FILE_PATH: $ACTIVE_PRD_PATH
PROGRESS_FILE_PATH: $ACTIVE_PROGRESS_PATH
PROJECT_ROOT: $SCRIPT_DIR/.."

  # Run Claude Code with timing, heartbeat, and stuck detection
  echo -e "${YELLOW}Starting Claude Code session...${NC}"
  echo ""

  ITERATION_START_TIME=$(date +%s)
  OUTPUT_FILE=$(mktemp)
  RETRY_COUNT=0
  MAX_RETRIES=3
  SESSION_SUCCESS=false

  while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$SESSION_SUCCESS" = "false" ]; do
    if [ $RETRY_COUNT -gt 0 ]; then
      echo -e "${YELLOW}Retry attempt $RETRY_COUNT of $MAX_RETRIES...${NC}"
      sleep 5
    fi

    # Start heartbeat
    start_heartbeat "$NEXT_TASK_ID"

    # Run claude in background so we can monitor for errors
    claude --dangerously-skip-permissions -p "$FULL_PROMPT" > "$OUTPUT_FILE" 2>&1 &
    CLAUDE_PID=$!

    # Monitor for error patterns that indicate a stuck/failed session
    STUCK_DETECTED=false
    while kill -0 $CLAUDE_PID 2>/dev/null; do
      sleep 5

      # Check for error patterns that cause hangs
      if grep -qE "(Error: No messages returned|ECONNRESET|socket hang up)" "$OUTPUT_FILE" 2>/dev/null; then
        # Before killing, check if the current task was already completed
        if task_is_complete "$ACTIVE_PRD_PATH" "$NEXT_TASK_ID"; then
          echo ""
          echo -e "${GREEN}Task completed despite error pattern in output - continuing...${NC}"
          # Don't kill - let session finish naturally
          continue
        fi

        # Also check if ALL tasks are now complete
        if all_complete "$ACTIVE_PRD_PATH"; then
          echo ""
          echo -e "${GREEN}All tasks complete - allowing session to finish...${NC}"
          continue
        fi

        # Only now kill the session - task is incomplete and error pattern detected
        echo ""
        echo -e "${RED}Detected error pattern and task incomplete - restarting session...${NC}"
        kill $CLAUDE_PID 2>/dev/null || true
        wait $CLAUDE_PID 2>/dev/null || true
        STUCK_DETECTED=true
        break
      fi
    done

    # Stop heartbeat
    stop_heartbeat

    if [ "$STUCK_DETECTED" = "true" ]; then
      RETRY_COUNT=$((RETRY_COUNT + 1))
      > "$OUTPUT_FILE"  # Clear output file for retry
    else
      # Claude exited normally
      wait $CLAUDE_PID
      EXIT_CODE=$?
      if [ $EXIT_CODE -eq 0 ]; then
        echo ""
        echo -e "${GREEN}Session completed${NC}"
      else
        echo ""
        echo -e "${YELLOW}Session exited (code: $EXIT_CODE)${NC}"
      fi
      SESSION_SUCCESS=true
      # Print captured output
      cat "$OUTPUT_FILE"
    fi
  done

  if [ "$SESSION_SUCCESS" = "false" ]; then
    echo -e "${RED}Failed after $MAX_RETRIES retries. Moving to next iteration...${NC}"
    # Append failure to progress log
    echo "" >> "$ACTIVE_PROGRESS_PATH"
    echo "## Iteration: $NEXT_TASK_ID (FAILED)" >> "$ACTIVE_PROGRESS_PATH"
    echo "Date: $(date)" >> "$ACTIVE_PROGRESS_PATH"
    echo "Task: $NEXT_TASK_TITLE" >> "$ACTIVE_PROGRESS_PATH"
    echo "" >> "$ACTIVE_PROGRESS_PATH"
    echo "### Failure Summary" >> "$ACTIVE_PROGRESS_PATH"
    echo "- Claude session stuck/unresponsive after $MAX_RETRIES retry attempts" >> "$ACTIVE_PROGRESS_PATH"
    echo "- Skipping to next iteration for fresh attempt" >> "$ACTIVE_PROGRESS_PATH"
    echo "" >> "$ACTIVE_PROGRESS_PATH"
    echo "---" >> "$ACTIVE_PROGRESS_PATH"
  fi

  # Calculate duration
  ITERATION_END_TIME=$(date +%s)
  ITERATION_DURATION=$((ITERATION_END_TIME - ITERATION_START_TIME))
  FORMATTED_DURATION=$(format_duration $ITERATION_DURATION)

  echo -e "${GRAY}  Duration: ${FORMATTED_DURATION}${NC}"

  # Check for completion signal (must be on its own line near the end, not just mentioned in text)
  if tail -5 "$OUTPUT_FILE" 2>/dev/null | grep -qx "<promise>COMPLETE</promise>"; then
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
  if all_complete "$ACTIVE_PRD_PATH"; then
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
  echo -e "After iteration $i: ${GREEN}$(count_tasks "$ACTIVE_PRD_PATH")${NC} complete (took ${FORMATTED_DURATION})"

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
echo -e "Final: ${YELLOW}$(count_tasks "$ACTIVE_PRD_PATH")${NC} complete"
echo ""
echo "Resume with: ./ralph.sh $PRD_INPUT_PATH"
exit 1
