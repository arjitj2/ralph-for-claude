#!/bin/bash
# Ralph Setup - Archive old run and set up new PRD
# Usage: ./setup.sh <path-to-prd.json>
# Example: ./setup.sh ../tasks/prd-ranking-algorithm-redesign.json

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
TEMPLATE_FILE="$SCRIPT_DIR/progress.txt.template"
ARCHIVE_DIR="$SCRIPT_DIR/archive"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              Ralph Setup                              ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════╝${NC}"
echo ""

# Check for argument
if [ -z "$1" ]; then
  echo -e "${RED}Error: No PRD file specified${NC}"
  echo ""
  echo "Usage: ./setup.sh <path-to-prd.json>"
  echo "Example: ./setup.sh ../tasks/prd-ranking-algorithm-redesign.json"
  echo ""
  echo "Available PRDs in tasks/:"
  ls -1 "$SCRIPT_DIR/../tasks/"*.json 2>/dev/null | while read f; do
    echo "  - $(basename "$f")"
  done
  exit 1
fi

NEW_PRD="$1"

# Check if new PRD exists
if [ ! -f "$NEW_PRD" ]; then
  echo -e "${RED}Error: PRD file not found: $NEW_PRD${NC}"
  exit 1
fi

# Get feature name from new PRD
NEW_FEATURE=$(jq -r '.branchName // .featureName // "unknown"' "$NEW_PRD" 2>/dev/null)
echo -e "New feature: ${GREEN}$NEW_FEATURE${NC}"
echo ""

# Archive existing run if prd.json exists
if [ -f "$PRD_FILE" ]; then
  OLD_FEATURE=$(jq -r '.branchName // .featureName // "unknown"' "$PRD_FILE" 2>/dev/null)
  COMPLETED=$(jq '[.tasks[] | select(.passes == true)] | length' "$PRD_FILE" 2>/dev/null || echo "0")
  TOTAL=$(jq '.tasks | length' "$PRD_FILE" 2>/dev/null || echo "0")

  echo -e "${YELLOW}Found existing run: $OLD_FEATURE ($COMPLETED/$TOTAL complete)${NC}"

  # Create archive folder
  DATE=$(date +%Y-%m-%d_%H%M%S)
  FOLDER_NAME=$(echo "$OLD_FEATURE" | sed 's|^feature/||' | sed 's|/|_|g')
  ARCHIVE_FOLDER="$ARCHIVE_DIR/$DATE-$FOLDER_NAME"

  mkdir -p "$ARCHIVE_FOLDER"

  # Move files to archive
  echo -e "Archiving to: ${BLUE}$ARCHIVE_FOLDER${NC}"
  mv "$PRD_FILE" "$ARCHIVE_FOLDER/"
  [ -f "$PROGRESS_FILE" ] && mv "$PROGRESS_FILE" "$ARCHIVE_FOLDER/"

  echo -e "${GREEN}Archived successfully${NC}"
  echo ""
fi

# Copy new PRD
echo -e "Setting up new PRD..."
cp "$NEW_PRD" "$PRD_FILE"
echo -e "  Copied: ${GREEN}$(basename "$NEW_PRD")${NC} -> ${GREEN}prd.json${NC}"

# Create fresh progress.txt from template
if [ -f "$TEMPLATE_FILE" ]; then
  cp "$TEMPLATE_FILE" "$PROGRESS_FILE"
else
  # Create default if template doesn't exist
  cat > "$PROGRESS_FILE" << 'EOF'
# Ralph Progress Log
Feature: (will be updated)
Started: (will be updated)

## Codebase Patterns

(Patterns discovered during implementation will be added here)

---

EOF
fi

# Update progress.txt with feature info
sed -i '' "s|Feature: .*|Feature: $NEW_FEATURE|" "$PROGRESS_FILE"
sed -i '' "s|Started: .*|Started: $(date)|" "$PROGRESS_FILE"

echo -e "  Created: ${GREEN}progress.txt${NC}"
echo ""

# Show task summary
TOTAL=$(jq '.tasks | length' "$PRD_FILE")
echo -e "${BLUE}PRD Summary:${NC}"
echo -e "  Feature: $NEW_FEATURE"
echo -e "  Tasks: $TOTAL"
echo ""
echo -e "${BLUE}Tasks:${NC}"
jq -r '.tasks[] | "  [\(if .passes then "x" else " " end)] \(.id): \(.title)"' "$PRD_FILE"
echo ""

echo -e "${GREEN}╔═══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Setup complete! Run ./ralph.sh to start              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════╝${NC}"
