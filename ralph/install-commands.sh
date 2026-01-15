#!/bin/bash
# Install Ralph commands to ~/.claude/commands/
# Run this script when you clone a project that already has ralph/ set up

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMANDS_DIR="$HOME/.claude/commands"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Installing Ralph commands..."
echo ""

# Create commands directory if it doesn't exist
mkdir -p "$COMMANDS_DIR"

# Find commands - check relative to ralph/ directory
# Commands should be in ../commands/ (sibling to ralph/)
if [ -d "$SCRIPT_DIR/../commands" ]; then
    RALPH_COMMANDS_DIR="$SCRIPT_DIR/../commands"
elif [ -d "$SCRIPT_DIR/commands" ]; then
    RALPH_COMMANDS_DIR="$SCRIPT_DIR/commands"
else
    echo "Error: Could not find commands directory"
    echo "Expected at: $SCRIPT_DIR/../commands"
    exit 1
fi

# Create symlinks to command files (so updates propagate automatically)
for cmd in "$RALPH_COMMANDS_DIR"/*.md; do
    if [ -f "$cmd" ]; then
        filename=$(basename "$cmd")
        ln -sf "$cmd" "$COMMANDS_DIR/$filename"
        echo -e "  ${GREEN}→${NC} Linked: $filename"
    fi
done

echo ""
echo -e "${GREEN}Done!${NC} Commands symlinked to $COMMANDS_DIR"
echo ""
echo "Available commands in Claude Code:"
echo "  /generate-prd         - Create a new PRD through interactive questions"
echo "  /convert-prd-to-json  - Convert markdown PRD to JSON for Ralph"
echo ""
