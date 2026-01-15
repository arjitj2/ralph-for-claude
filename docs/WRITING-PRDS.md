# Writing Effective PRDs for Ralph

This guide helps you write PRDs that Ralph can execute effectively.

## Task Sizing

Each task should be completable in **one Claude Code session** (one context window).

### Signs a task is too big:
- More than 5 acceptance criteria
- Touches more than 3-4 files
- Can't describe the change in 2-3 sentences
- Requires understanding a large amount of context

### Signs a task is too small:
- Just a one-line change
- No meaningful acceptance criteria
- Could easily be combined with related work

### Right-sized examples:

**Good:**
```json
{
  "id": "US-001",
  "title": "Add login form validation",
  "acceptanceCriteria": [
    "Email field validates format",
    "Password field requires 8+ characters",
    "Submit button disabled until valid",
    "Error messages display below fields"
  ]
}
```

**Too big:**
```json
{
  "id": "US-001",
  "title": "Implement authentication system",
  "acceptanceCriteria": [
    "Login form with validation",
    "Registration form",
    "Password reset flow",
    "Session management",
    "OAuth integration",
    "Role-based permissions"
  ]
}
```

## Acceptance Criteria

Write criteria that are **specific** and **verifiable**.

### Good criteria:
- "Button shows loading spinner while submitting"
- "API returns 200 with user object containing id, email, name"
- "Invalid credentials display error message 'Invalid email or password'"
- "Form clears after successful submission"

### Bad criteria:
- "Works correctly" (vague)
- "Handles edge cases" (unspecified)
- "Is well-tested" (subjective)
- "Good UX" (unmeasurable)

## Dependencies

Order tasks so dependencies flow naturally:

1. **Schema/Data model** - No dependencies
2. **Backend/Services** - Depends on schema
3. **UI Components** - Depends on backend
4. **Tests** - Depends on implementation

### Example dependency chain:

```json
{
  "tasks": [
    {"id": "US-001", "title": "Add User model", "dependsOn": []},
    {"id": "US-002", "title": "Add AuthService", "dependsOn": ["US-001"]},
    {"id": "US-003", "title": "Add LoginForm", "dependsOn": ["US-002"]},
    {"id": "US-004", "title": "Add auth tests", "dependsOn": ["US-002", "US-003"]}
  ]
}
```

## PRD Structure

Use the `/generate-prd` command to create PRDs with this structure:

```markdown
# PRD: Feature Name

## 1. Overview
Brief description of the feature.

## 2. Goals
- Goal 1
- Goal 2
- Non-goal: What this doesn't include

## 3. User Stories

### US-001: Title
**As a** [user type]
**I want** [capability]
**So that** [benefit]

**Acceptance Criteria:**
- [ ] Criterion 1
- [ ] Criterion 2

## 4. Technical Considerations
- Dependencies
- Performance requirements
- Data model changes
```

## Tips for Ralph Success

1. **Include test requirements** - If tests are needed, make them explicit acceptance criteria

2. **Reference existing code** - "Follow the pattern in `src/services/UserService.ts`"

3. **Be specific about files** - "Add to `src/models/User.ts`" not just "add a model"

4. **Include verification steps** - "Run `npm test` to verify" as a criterion

5. **One concern per task** - Don't mix unrelated changes

## Common Mistakes

### Mistake: Vague scope
```json
"title": "Improve performance"
```
**Fix:** Be specific: "Add caching to UserService.getById()"

### Mistake: Hidden dependencies
```json
{"id": "US-002", "title": "Add UI", "dependsOn": []}  // Actually needs US-001
```
**Fix:** Always trace what this task needs to exist first

### Mistake: Testing as afterthought
```json
"acceptanceCriteria": ["Feature works", "Has tests"]
```
**Fix:** Make tests specific: "Unit tests for all public methods with >80% coverage"
