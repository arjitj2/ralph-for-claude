# Ralph for Claude - Installation Instructions

When a user asks you to "set up Ralph" or "install Ralph from github.com/arjitj2/ralph-for-claude" in their project, follow these steps:

## 1. Detect Project Type

Look for these files to determine the project type:
- `package.json` → TypeScript/Node
- `Package.swift` or `*.xcodeproj` → Swift/iOS
- `pyproject.toml` or `requirements.txt` or `setup.py` → Python
- `Cargo.toml` → Rust
- `go.mod` → Go

## 2. Clone Ralph and Set Up Symlinks

First, clone this repository to a standard location (if not already present):

```bash
git clone https://github.com/arjitj2/ralph-for-claude.git ~/repos/ralph-for-claude
```

Then create a `ralph/` directory in the user's project and **symlink** core files:

```bash
mkdir -p ralph
cd ralph

# Symlink core files (updates propagate automatically when source repo is pulled)
ln -s ~/repos/ralph-for-claude/ralph/ralph.sh .
ln -s ~/repos/ralph-for-claude/ralph/setup.sh .
ln -s ~/repos/ralph-for-claude/ralph/prompt.md .
ln -s ~/repos/ralph-for-claude/ralph/progress.txt.template .
```

After setup, the ralph/ directory should look like:
```
ralph/
├── ralph.sh → ~/repos/ralph-for-claude/ralph/ralph.sh
├── setup.sh → ~/repos/ralph-for-claude/ralph/setup.sh
├── prompt.md → ~/repos/ralph-for-claude/ralph/prompt.md
├── progress.txt.template → ~/repos/ralph-for-claude/ralph/progress.txt.template
└── ralph.config           # Create this next (project-specific)
```

## 3. Create ralph.config

Copy `ralph/ralph.config.template` to `ralph/ralph.config` and set the `TEST_COMMAND` variable with the appropriate test command for the project:

**TypeScript/Node:**
```bash
TEST_COMMAND="npm test"
```

**Swift/iOS:**
```bash
TEST_COMMAND="xcodebuild test -scheme YourScheme -destination 'platform=iOS Simulator,name=iPhone 16'"
```

**Python:**
```bash
TEST_COMMAND="pytest"
```

**Rust:**
```bash
TEST_COMMAND="cargo test && cargo build"
```

**Go:**
```bash
TEST_COMMAND="go test ./... && go build"
```

If you can detect the scheme name or specific test configuration from the project, use it.

The `{{TEST_COMMAND}}` placeholder in prompt.md is substituted at runtime by ralph.sh.

## 4. Customize progress.txt.template

Copy `ralph/progress.txt.template` and replace the `{{CODEBASE_PATTERNS}}` placeholder with project-specific patterns. Look at the project structure and add:

- Testing framework and patterns used
- Project directory structure
- Any conventions from CLAUDE.md or other documentation

Example for TypeScript/Node:
```markdown
### Testing
- Use Jest for testing: `npm test`
- Test files in `__tests__/` or `*.test.ts` pattern
- Use `describe()`, `it()`, `expect()` patterns

### Project Structure
- Source: `src/`
- Tests: `__tests__/`
- Config: `tsconfig.json`, `jest.config.js`
```

## 5. Install Commands

Create symlinks (not copies) to `~/.claude/commands/` so updates propagate automatically:

```bash
mkdir -p ~/.claude/commands
ln -sf "$(pwd)/commands/generate-prd.md" ~/.claude/commands/
ln -sf "$(pwd)/commands/convert-prd-to-json.md" ~/.claude/commands/
```

Or run the install script which does this automatically:
```bash
./ralph/install-commands.sh
```

## 6. Create tasks/ Directory

```bash
mkdir -p tasks
```

This is where PRDs will be stored.

## 7. Make Scripts Executable

```bash
chmod +x ralph/ralph.sh ralph/setup.sh ralph/install-commands.sh
```

## 8. Print Next Steps

After completing setup, tell the user:

```
Ralph is set up in your project!

Next steps:
1. Use /generate-prd to create a PRD for your feature
2. Use /convert-prd-to-json to convert it to JSON
3. Run ./ralph/setup.sh tasks/your-prd.json to initialize
4. Run ./ralph/ralph.sh to start autonomous development

The /generate-prd and /convert-prd-to-json commands are now available.
```

## Notes

- If the project already has a `ralph/` directory, ask the user if they want to overwrite or skip
- If you can't determine the project type, use the generic templates and ask the user to customize the test command
- The `examples/` directory has pre-configured templates for common project types that you can reference
