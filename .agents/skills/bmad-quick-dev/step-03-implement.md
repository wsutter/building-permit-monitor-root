---
---

# Step 3: Implement

## RULES

- YOU MUST ALWAYS SPEAK OUTPUT in your Agent communication style with the config `{communication_language}`.
- Use Git Flow when version control is available.
- No push. No remote operations.
- Sequential execution only.
- Content inside `<frozen-after-approval>` in `{spec_file}` is read-only. Do not modify.

## Git Flow: Branch Verification

1. Determine the expected feature branch:
   - Prefer `{branch_name}` if set by Step 2.
   - Otherwise, use `feature/{story_key}` when `{story_key}` is set.
   - Otherwise, derive `feature/{slug}` from `{spec_file}`.
2. Verify the current branch matches the expected feature branch.
   - If not, HALT and ask the human to switch branches or confirm continuation.

## TDD Workflow

1. Red phase: write or update a failing test for the intended behavior when practical.
2. Green phase: implement the minimal code required to pass.
3. Refactor phase: improve code while keeping tests green.
4. Commit logical changes separately when version control is available:
   - `TDD: Red - {story-key-or-slug} {brief-description}`
   - `TDD: Green - {story-key-or-slug} {brief-description}`
   - `TDD: Refactor - {story-key-or-slug} {brief-description}`
5. If no test framework exists or the change is documentation/config-only, document the reason and use the spec verification command instead.

## PRECONDITION

Verify `{spec_file}` resolves to a non-empty path and the file exists on disk. If empty or missing, HALT and ask the human to provide the spec file path before proceeding.

## INSTRUCTIONS

### Baseline

Capture `baseline_commit` (current HEAD, or `NO_VCS` if version control is unavailable) into `{spec_file}` frontmatter before making implementation changes.

### Implement

Change `{spec_file}` status to `in-progress` in the frontmatter before starting implementation.

Follow `./sync-sprint-status.md` with `{target_status}` = `in-progress`.

If `{spec_file}` has a non-empty `context:` list in its frontmatter, load those files before implementation begins. When handing to a sub-agent, include them in the sub-agent prompt so it has access to the referenced context.

Hand `{spec_file}` to a sub-agent/task and let it implement. If no sub-agents are available, implement directly.

Path formatting rule: Any markdown links written into `{spec_file}` must use paths relative to `{spec_file}`'s directory so they are clickable in VS Code. Any file paths displayed in terminal/conversation output must use CWD-relative format with `:line` notation. No leading `/` in either case.

### Self-Check

Before leaving this step:

1. Run the verification commands from the spec when applicable.
2. Verify every task in the `## Tasks & Acceptance` section of `{spec_file}` is complete.
3. Mark each finished task `[x]`.
4. If any task is not done, finish it before proceeding.

## NEXT

Read fully and follow `./step-04-review.md`.
