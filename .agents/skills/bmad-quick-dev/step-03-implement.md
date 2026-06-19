---
---

# Step 3: Implement

### Git Flow: Branch Verification
1. Verify the current branch matches `feature/{story-key}`.
   - If not, halt and ask the user to switch branches.

## RULES

### TDD Workflow
1. **Red Phase (Write Failing Test First)**
   - Write a test that fails for the intended behavior.
   - Commit the failing test with the message:
     ```
     TDD: Red - Test for {story-key} {brief-description}
     ```
     Example:
     ```
     TDD: Red - Test for 1-1-csv-mapping field validation
     ```

2. **Green Phase (Minimal Implementation)**
   - Implement the minimal code required to pass the test.
   - Commit the passing implementation with the message:
     ```
     TDD: Green - Implement {story-key} {brief-description}
     ```
     Example:
     ```
     TDD: Green - Implement 1-1-csv-mapping field validation
     ```

3. **Refactor Phase (Improve Code)**
   - Refactor the implementation while keeping tests green.
   - Commit refactored code with the message:
     ```
     TDD: Refactor - {story-key} {brief-description}
     ```
     Example:
     ```
     TDD: Refactor - 1-1-csv-mapping field validation
     ```

4. **Test Coverage**
   - Ensure all new functionality is covered by tests.
   - If a test framework is not set up, halt and ask the user to configure it.

### Git Commit Discipline
- **Atomic Commits**: Every logical change (test, implementation, refactor) must be a separate commit.
- **Meaningful Commit Messages**: Use the format:
  ```
  {step}: {story-key} - {brief-description}
  ```
- **Error Handling**:
  - If a test fails unexpectedly, halt and ask the user to debug before proceeding.
  - If Git operations fail, halt and ask for manual intervention.

- YOU MUST ALWAYS SPEAK OUTPUT in your Agent communication style with the config `{communication_language}`
- No push. No remote ops.
- Sequential execution only.
- Content inside `<frozen-after-approval>` in `{spec_file}` is read-only. Do not modify.

## PRECONDITION

Verify `{spec_file}` resolves to a non-empty path and the file exists on disk. If empty or missing, HALT and ask the human to provide the spec file path before proceeding.

## INSTRUCTIONS

### Baseline

Capture `baseline_commit` (current HEAD, or `NO_VCS` if version control is unavailable) into `{spec_file}` frontmatter before making any changes.

### Implement

Change `{spec_file}` status to `in-progress` in the frontmatter before starting implementation.

Follow `./sync-sprint-status.md` with `{target_status}` = `in-progress`.

If `{spec_file}` has a non-empty `context:` list in its frontmatter, load those files before implementation begins. When handing to a sub-agent, include them in the sub-agent prompt so it has access to the referenced context.

Hand `{spec_file}` to a sub-agent/task and let it implement. If no sub-agents are available, implement directly.

**Path formatting rule:** Any markdown links written into `{spec_file}` must use paths relative to `{spec_file}`'s directory so they are clickable in VS Code. Any file paths displayed in terminal/conversation output must use CWD-relative format with `:line` notation (e.g., `src/path/file.ts:42`) for terminal clickability. No leading `/` in either case.

### Self-Check

Before leaving this step, verify every task in the `## Tasks & Acceptance` section of `{spec_file}` is complete. Mark each finished task `[x]`. If any task is not done, finish it before proceeding.

## NEXT

Read fully and follow `./step-04-review.md`
