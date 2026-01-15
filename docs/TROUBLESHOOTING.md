# Troubleshooting Ralph

Common issues and solutions when running Ralph.

## Setup Issues

### "Error: No prd.json found in ralph/"

**Cause:** You haven't initialized a PRD yet.

**Solution:**
```bash
./ralph/setup.sh tasks/your-prd.json
```

### "Error: prompt.md not found"

**Cause:** The prompt template wasn't copied to your project.

**Solution:** Copy from examples:
```bash
cp examples/typescript-node/prompt.md ralph/prompt.md
```

### Commands not available (/generate-prd not found)

**Cause:** Commands weren't installed to `~/.claude/commands/`

**Solution:**
```bash
./ralph/install-commands.sh
```

Then restart Claude Code for commands to take effect.

## Runtime Issues

### Ralph stuck on same task

**Cause:** Tests are failing or acceptance criteria not met.

**Check:**
1. Look at `ralph/progress.txt` for error details
2. Run tests manually to see failures
3. Check if PRD was updated (`"passes": true`)

**Solution:** Fix the failing tests or adjust acceptance criteria.

### "No eligible tasks (blocked by dependencies)"

**Cause:** A task's dependencies haven't been completed yet.

**Check:** Look at `prd.json` - the tasks in `dependsOn` array must all have `"passes": true`

**Solution:** Either:
- Complete the blocking task manually
- Adjust dependencies in the PRD

### Iteration taking too long

**Cause:** Task is too large or complex.

**Solution:** Break the task into smaller sub-tasks with their own acceptance criteria.

### Changes not being committed

**Cause:** Tests may be failing silently, or commit step being skipped.

**Check:**
- Run `git status` to see uncommitted changes
- Check `ralph/progress.txt` for errors

**Solution:** Run tests manually, fix failures, then run Ralph again.

## PRD Issues

### Tasks completing but feature not working

**Cause:** Acceptance criteria are too vague or incomplete.

**Solution:** Add more specific, verifiable acceptance criteria:
- Bad: "Feature works"
- Good: "API returns 200 with user object containing id, email, name"

### Wrong task order

**Cause:** Dependencies not set correctly.

**Solution:** Review `dependsOn` arrays. Tasks should build on each other:
1. Schema/models (no deps)
2. Services (depends on models)
3. UI (depends on services)
4. Tests (depends on implementation)

## Test Issues

### Tests passing in Ralph but failing manually

**Cause:** Different test environment or missing setup.

**Check:** Compare the test command in `prompt.md` with your manual command.

### Tests timing out

**Cause:** Test command taking too long.

**Solution:** Add timeout to Ralph:
```bash
./ralph/ralph.sh 5  # 5 iterations max
```

Or adjust timeout in `ralph.sh`.

## Recovery

### Resetting a failed run

If Ralph gets stuck, you can reset:

1. Archive the current run:
   ```bash
   ./ralph/setup.sh tasks/your-prd.json  # Re-run setup
   ```

2. Or manually reset task status:
   ```bash
   # Edit ralph/prd.json
   # Change "passes": true back to "passes": false for tasks to retry
   ```

### Starting fresh

To completely reset:
```bash
rm ralph/prd.json ralph/progress.txt
./ralph/setup.sh tasks/your-prd.json
```

## Getting Help

1. Check `ralph/progress.txt` for detailed iteration logs
2. Review git history for what was committed
3. Open an issue at github.com/arjitj2/ralph-for-claude
