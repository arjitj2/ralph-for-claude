# Convert PRD to JSON Skill

Convert a markdown PRD document into a structured `prd.json` file for autonomous execution.

## Your Role

You are converting a human-readable PRD into a machine-readable task list that can drive autonomous development loops like Ralph.

## Input

The user will provide a path to a markdown PRD file (e.g., `tasks/prd-feature-name.md`).

Read this file first to understand all the user stories and requirements.

## Process

### Step 1: Read the PRD

Use the Read tool to get the full PRD content.

### Step 2: Extract User Stories

For each user story in the PRD, create a task object with:
- `id`: Use the story ID from the PRD (e.g., `US-001`, `US-002`) - these should already be in the markdown
- `title`: Short descriptive title
- `description`: The full user story ("As a... I want... So that...")
- `acceptanceCriteria`: Array of verifiable criteria from the PRD
- `dependsOn`: Array of task IDs this depends on (empty for first tasks)
- `passes`: Always `false` initially (not yet completed)

**Important**: Preserve the `US-XXX` IDs from the PRD. Do NOT convert to kebab-case.

### Step 3: Determine Dependencies

Order tasks based on logical dependencies:
1. Schema/data model changes have no dependencies
2. Backend services depend on schema changes
3. UI components depend on backend services
4. Tests depend on the features they test

### Step 4: Generate prd.json

Create the JSON file with this structure:

```json
{
  "featureName": "Feature Name",
  "branchName": "feature/feature-name",
  "createdAt": "2025-01-14",
  "description": "Brief description from PRD overview",
  "tasks": [
    {
      "id": "US-001",
      "title": "Add User Model",
      "description": "As a developer, I want a user data model so that I can store user information",
      "acceptanceCriteria": [
        "User model has id, email, name fields",
        "Model is persisted to database"
      ],
      "dependsOn": [],
      "passes": false
    },
    {
      "id": "US-002",
      "title": "Add Login Form",
      "description": "As a user, I want a login form so that I can authenticate",
      "acceptanceCriteria": [
        "Form has email and password fields",
        "Submit button triggers authentication"
      ],
      "dependsOn": ["US-001"],
      "passes": false
    }
  ]
}
```

## Key Requirements

### Tasks Must Be Right-Sized

Each task must be completable in ONE context window (~one focused Claude session).

Signs a task is too big:
- More than 5 acceptance criteria
- Touches more than 3-4 files
- Can't describe the change in 2-3 sentences

If a task is too big, split it into smaller tasks.

### Branch Naming

Use kebab-case for branch name: `feature/add-user-auth`, `fix/login-bug`, `refactor/api-cleanup`

### Acceptance Criteria Format

Each criterion should be a single verifiable statement:
- "Login form has email and password fields"
- "Invalid credentials show error message"
- "Successful login redirects to dashboard"

NOT:
- "Works correctly"
- "Handles edge cases"
- "Is well-tested"

### Dependency Rules

- First task(s) should have `"dependsOn": []`
- Later tasks reference earlier task IDs
- Parallel tasks can share the same dependencies
- Circular dependencies are not allowed

## Output

1. Write the JSON file to the **same directory** as the input markdown file, with the **same base name** but `.json` extension
   - Example: `tasks/prd-feature-name.md` → `tasks/prd-feature-name.json`
   - Do NOT default to `prd.json` - always match the source filename
2. Display a summary showing:
   - Number of tasks created
   - Dependency graph (text format)
   - Any warnings about task sizing

## Example Output Summary

```
Created tasks/prd-user-auth.json with 6 tasks:

Dependency Graph:
  US-001 Add User Model (no deps)
  └── US-002 Add Auth Service (depends on: US-001)
      └── US-003 Add Login Form (depends on: US-002)
      └── US-004 Add Signup Form (depends on: US-002)
          └── US-005 Add Auth Tests (depends on: US-003, US-004)
              └── US-006 Add E2E Tests (depends on: US-005)

Ready for autonomous execution with Ralph.
```

## Integration with Ralph

After creating the JSON file, initialize and run Ralph:
```bash
./ralph/setup.sh tasks/prd-your-feature.json  # Initialize with your PRD
./ralph/ralph.sh                               # Start autonomous execution
```

Ralph will:
1. Pick the first task with `passes: false` and satisfied dependencies
2. Implement it in a fresh context
3. Run checks (typecheck, tests)
4. Mark `passes: true` if successful
5. Loop until all tasks complete

## Validation Checklist

Before saving, verify:
- [ ] All task IDs are unique
- [ ] All dependsOn references exist
- [ ] No circular dependencies
- [ ] Each task has at least one acceptance criterion
- [ ] Branch name is valid kebab-case
