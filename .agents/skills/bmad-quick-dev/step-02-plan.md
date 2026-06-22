---
deferred_work_file: '{implementation_artifacts}/deferred-work.md'
branch_name: '' # set at runtime to feature/{story-key-or-slug}
base_branch: '' # set at runtime to develop if present, otherwise main
---

# Step 2: Plan

## RULES

- YOU MUST ALWAYS SPEAK OUTPUT in your Agent communication style with the config `{communication_language}`.
- No intermediate approvals except the explicit approval checkpoint in this step.
- Use Git Flow when version control is available.
- Never push, merge, delete branches, or create pull requests without explicit human confirmation.

## Git Flow: Feature Branch Creation

1. Determine `{base_branch}`:
   - Prefer `develop` when it exists locally or on `origin/develop`.
   - Otherwise use `main` when it exists locally or on `origin/main`.
   - If neither can be determined, HALT and ask the human which base branch to use.
2. Verify the current branch is `{base_branch}`.
   - If not, HALT and ask the human whether to switch to `{base_branch}` or continue from the current branch.
3. Determine `{branch_name}`:
   - If `{story_key}` is set, use `feature/{story_key}`.
   - Otherwise, derive the same kebab-case slug used for `{spec_file}` and use `feature/{slug}`.
4. Create or check out `{branch_name}` from `{base_branch}`:
   - If the branch exists, check it out.
   - If it does not exist, create it from `{base_branch}`.
   - If creation or checkout fails, HALT and ask for manual intervention.

## TDD: Test Planning

1. Define test cases before implementation.
2. Cover happy paths, edge cases, and error scenarios.
3. If the repository has no applicable test framework, document the best available verification command in the spec instead of inventing one.

## INSTRUCTIONS

1. Draft resume check. If `{spec_file}` exists with `status: draft`, read it and capture the verbatim `<frozen-after-approval>...</frozen-after-approval>` block as `preserved_intent`. Otherwise `preserved_intent` is empty.
2. Investigate codebase. Isolate deep exploration in sub-agents/tasks where available. To prevent context snowballing, instruct subagents to give distilled summaries only.
3. Read `./spec-template.md` fully. Fill it out based on the intent and investigation. If `{preserved_intent}` is non-empty, substitute it for the `<frozen-after-approval>` block in your filled spec before writing. Write the result to `{spec_file}`.
4. Add planned verification commands to `## Verification`, including the relevant module command such as `mvn -B verify` for Java modules.
5. Self-review against READY FOR DEVELOPMENT standard.
6. If intent gaps exist, do not fantasize, do not leave open questions, HALT and ask the human.
7. Token count check (see SCOPE STANDARD). If spec exceeds 1600 tokens:
   - Show user the token count.
   - HALT and ask human: `[S] Split — carve off secondary goals` | `[K] Keep full spec — accept the risks`
   - On **S**: Propose the split, append deferred goals to `{deferred_work_file}`, regenerate the spec for the narrowed scope, then continue to checkpoint.
   - On **K**: Continue to checkpoint with full spec.
8. If version control is available and the spec file changed, commit the spec with:
   - `Plan: {story-key-or-slug} - {brief-description}`

## CHECKPOINT 1

Present summary. Display the spec file path as a CWD-relative path with no leading `/` so it is clickable in the terminal. If token count exceeded 1600 and user chose [K], include the token count and explain why it may be a problem.

After presenting the summary, display this note:

Before approving, you can open the spec file in an editor or ask me questions and tell me what to change. You can also use `bmad-advanced-elicitation`, `bmad-party-mode`, or `bmad-code-review` skills, ideally in another session to avoid context bloat.

HALT and ask human: `[A] Approve` | `[E] Edit`

- **A**: Re-read `{spec_file}` from disk.
  - **If the file is missing:** HALT. Tell the user the spec file is gone and STOP — do not write anything to `{spec_file}`, do not set status, do not proceed to Step 3.
  - **If the file exists:** Compare the content to what you wrote. If it has changed since you wrote it, acknowledge the external edits with a brief summary and proceed with the updated version. Then set status `ready-for-dev` in `{spec_file}`. Everything inside `<frozen-after-approval>` is now locked — only the human can change it. Continue to Step 3.
- **E**: Apply changes, then return to CHECKPOINT 1.

## NEXT

Read fully and follow `./step-03-implement.md`.
