# Ralph for Claude - Installation Instructions

When a user asks you to "set up Ralph" or "install Ralph from github.com/arjitj2/ralph-for-claude" in their project, follow these steps:

## 1. Detect Project Type

Look for these files to determine the project type:
- `package.json` → TypeScript/Node
- `Package.swift` or `*.xcodeproj` → Swift/iOS
- `pyproject.toml` or `requirements.txt` or `setup.py` → Python
- `Cargo.toml` → Rust
- `go.mod` → Go

## 2. Fetch and Copy Core Files

First, fetch this repository. Then copy the `ralph/` directory to the user's project root:

```
ralph/
├── ralph.sh                 # Copy as-is
├── setup.sh                 # Copy as-is
├── install-commands.sh      # Copy as-is
├── prompt.md.template       # Customize → prompt.md
└── progress.txt.template    # Customize → progress.txt.template
```

## 3. Customize prompt.md

Copy `ralph/prompt.md.template` to `ralph/prompt.md` and replace the `{{TEST_COMMAND}}` placeholder with the appropriate test command:

**TypeScript/Node:**
```bash
npm test
npm run build  # if applicable
npm run lint   # if applicable
```

**Swift/iOS:**
```bash
xcodebuild test -scheme YourScheme -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Python:**
```bash
pytest
```

**Rust:**
```bash
cargo test
cargo build
```

**Go:**
```bash
go test ./...
go build
```

If you can detect the scheme name or specific test configuration from the project, use it.

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

Copy the commands to `~/.claude/commands/`:

```bash
mkdir -p ~/.claude/commands
cp commands/generate-prd.md ~/.claude/commands/
cp commands/convert-prd-to-json.md ~/.claude/commands/
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
