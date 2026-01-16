# Ralph for Claude

An autonomous AI coding agent that implements features from a PRD (Product Requirements Document) through iterative Claude Code sessions.

> **Attribution**: This project is adapted from [snarktank/ralph](https://github.com/snarktank/ralph). Thank you to the original authors for the concept of PRD-driven autonomous development loops.

## What is Ralph?

Ralph is a workflow pattern that enables Claude Code to autonomously implement features by:

1. **Reading a PRD** - A structured JSON file with tasks, dependencies, and acceptance criteria
2. **Implementing one task per iteration** - Fresh context each time, focused work
3. **Running tests** - Ensuring quality before marking tasks complete
4. **Tracking progress** - Updating the PRD and progress log
5. **Looping until done** - Continuing until all tasks pass

The core insight is that progress should be stored in files, not in context. Fresh context for each task gives Claude the best chance of not getting lost.

## Quick Start

### Option A: Claude-Assisted Install (Recommended)

In your project directory, tell Claude:

```
Set up Ralph from github.com/arjitj2/ralph-for-claude in my project
```

Claude will read this repo's `CLAUDE.md` and:
1. Clone ralph-for-claude repo locally (if not already present)
2. Create symlinks from your project's `ralph/` to the source (for automatic updates)
3. Create `ralph.config` with your project's test command
4. Install command symlinks to `~/.claude/commands/`

### Option B: Manual Setup

1. Clone this repo (keep it - you'll symlink to it):
   ```bash
   git clone https://github.com/arjitj2/ralph-for-claude.git ~/repos/ralph-for-claude
   ```

2. Create `ralph/` directory in your project and symlink core files:
   ```bash
   mkdir -p your-project/ralph
   cd your-project/ralph
   ln -s ~/repos/ralph-for-claude/ralph/ralph.sh .
   ln -s ~/repos/ralph-for-claude/ralph/prompt.md .
   ln -s ~/repos/ralph-for-claude/ralph/progress.txt.template .
   ```

3. Install commands (creates symlinks to `~/.claude/commands/`):
   ```bash
   ~/repos/ralph-for-claude/ralph/install-commands.sh
   ```

4. Create `ralph/ralph.config` with your test command:
   ```bash
   cat > ralph.config << 'EOF'
   TEST_COMMAND="npm test"  # Replace with your project's test command
   EOF
   ```

**Why symlinks?** Updates to ralph-for-claude automatically apply to all your projects. Only `ralph.config` is project-specific.

## Workflow

### 1. Generate a PRD

In Claude Code, use the `/generate-prd` command:

```
/generate-prd
```

This will ask questions and create `tasks/prd-your-feature.md`.

### 2. Convert to JSON

Use the `/convert-prd-to-json` command:

```
/convert-prd-to-json tasks/prd-your-feature.md
```

This creates `tasks/prd-your-feature.json` with structured tasks.

### 3. Run Ralph

```bash
./ralph/ralph.sh tasks/prd-your-feature.json
```

That's it! Ralph will:
- Validate the PRD
- Create an archive folder for this run
- Find the first incomplete task
- Start a Claude Code session to implement it
- Track progress and loop until done

### 4. Resume If Interrupted

If you stop Ralph mid-run, just run the same command again:

```bash
./ralph/ralph.sh tasks/prd-your-feature.json
```

Ralph automatically detects incomplete runs and resumes where it left off.

### 5. Monitor Progress

Watch the terminal output, or check:
- `ralph/archive/<timestamp>-<feature>/prd.json` - Task completion status
- `ralph/archive/<timestamp>-<feature>/progress.txt` - Detailed iteration logs
- Git history - Commits per task

## Archive Structure

Each run is stored immediately in the archive folder:

```
ralph/archive/
├── 2025-01-15_1430-ui-polish/
│   ├── prd-ui-polish.json     # PRD copy (updated as tasks complete)
│   └── progress.txt           # Iteration logs
├── 2025-01-15_1645-auth-flow/
│   ├── prd-auth-flow.json
│   └── progress.txt
```

This means:
- No separate "setup" step needed
- Progress is saved from the start
- Resuming is automatic
- History is preserved

## File Structure

After setup, your project will have:

```
your-project/
├── ralph/
│   ├── ralph.sh              # Main script (symlink to source)
│   ├── prompt.md             # Claude instructions (symlink to source)
│   ├── progress.txt.template # Template (symlink to source)
│   ├── ralph.config          # Project-specific test command
│   └── archive/              # All runs stored here
├── tasks/
│   ├── prd-feature.md        # Human-readable PRD
│   └── prd-feature.json      # Machine-readable PRD
└── ...
```

## Command Options

```bash
./ralph/ralph.sh <prd-filepath> [max_iterations]

# Examples:
./ralph/ralph.sh tasks/prd-ui-polish.json       # 10 iterations (default)
./ralph/ralph.sh tasks/prd-ui-polish.json 20    # Up to 20 iterations
./ralph/ralph.sh tasks/prd-ui-polish.md         # Auto-uses .json if exists
```

## For Collaborators

When you clone a project that already has `ralph/` set up:

```bash
./ralph/install-commands.sh
```

This creates **symlinks** from `~/.claude/commands/` to the repo's command files. Edits to commands in the source repo automatically apply everywhere.

## Tips for Writing Good PRDs

- **Right-size tasks**: Each task should be completable in one session
- **Clear acceptance criteria**: Specific, verifiable statements
- **Proper dependencies**: Schema → Backend → UI → Tests

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

Contributions welcome! Please open an issue or PR.
