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

## Quick Start

### Option A: Claude-Assisted Install (Recommended)

In your project directory, tell Claude:

```
Set up Ralph from github.com/arjitj2/ralph-for-claude in my project
```

Claude will read this repo's `CLAUDE.md` and:
1. Copy `ralph/` to your project
2. Install commands to `~/.claude/commands/`
3. Customize templates for your project type

### Option B: Manual Setup

1. Clone this repo:
   ```bash
   git clone https://github.com/arjitj2/ralph-for-claude.git
   ```

2. Copy `ralph/` to your project:
   ```bash
   cp -r ralph-for-claude/ralph your-project/
   ```

3. Install commands:
   ```bash
   ./your-project/ralph/install-commands.sh
   ```

4. Copy and customize a template from `examples/` to `your-project/ralph/prompt.md`

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

### 3. Set Up Ralph

```bash
./ralph/setup.sh tasks/prd-your-feature.json
```

This:
- Archives any previous PRD run
- Copies your PRD to `ralph/prd.json`
- Initializes `ralph/progress.txt`

### 4. Run Ralph

```bash
./ralph/ralph.sh
```

Ralph will:
- Find the first incomplete task
- Start a Claude Code session to implement it
- Track progress and loop until done

### 5. Monitor Progress

Watch the terminal output, or check:
- `ralph/prd.json` - Task completion status
- `ralph/progress.txt` - Detailed iteration logs
- Git history - Commits per task

## File Structure

After setup, your project will have:

```
your-project/
├── ralph/
│   ├── ralph.sh              # Main loop script
│   ├── setup.sh              # Initialize new PRD
│   ├── prompt.md             # Claude instructions
│   ├── progress.txt          # Iteration logs
│   ├── prd.json              # Current PRD (active)
│   └── archive/              # Previous runs
├── tasks/
│   ├── prd-feature.md        # Human-readable PRD
│   └── prd-feature.json      # Machine-readable PRD
└── ...
```

## For Collaborators

When you clone a project that already has `ralph/` set up:

```bash
./ralph/install-commands.sh
```

This installs the `/generate-prd` and `/convert-prd-to-json` commands to your `~/.claude/commands/`.

## Examples

Pre-configured templates are available in `examples/`:

- `swift-ios/` - Swift Testing, xcodebuild
- `typescript-node/` - Jest, npm
- `python/` - pytest

Copy the appropriate `prompt.md` and `progress.txt.template` to your `ralph/` directory.

## Tips for Writing Good PRDs

See [docs/WRITING-PRDS.md](docs/WRITING-PRDS.md) for best practices.

Key points:
- **Right-size tasks**: Each task should be completable in one session
- **Clear acceptance criteria**: Specific, verifiable statements
- **Proper dependencies**: Schema → Backend → UI → Tests

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

## License

MIT License - see [LICENSE](LICENSE)

## Contributing

Contributions welcome! Please open an issue or PR.
