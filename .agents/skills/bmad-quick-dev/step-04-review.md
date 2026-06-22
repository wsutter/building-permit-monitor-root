---
deferred_work_file: '{implementation_artifacts}/deferred-work.md'
specLoopIteration: 1
---

# Step 4: Review

## RULES

- YOU MUST ALWAYS SPEAK OUTPUT in your Agent communication style with the config `{communication_language}`.
- Review subagents get NO conversation context.
- All review subagents must run at the same model capability as the current session.
- Never push, merge, delete branches, or create pull requests without explicit human confirmation.

## Git Flow: Review Readiness

1. Ensure the current branch is the expected `feature/*` branch.
2. Ensure all implementation changes are committed locally where version control is available.
3. Do not push automatically. If a remote CI run is desired, present the push command to the user later in Step 5.

## TDD: Review and Test Validation

1. Run the verification commands from `{spec_file}`.
2. If any test fails, debug and fix when the fix is clearly within the approved spec.
3. Commit review fixes with:
   - `Review: {story-key-or-slug} - Address feedback for {brief-description}`

## INSTRUCTIONS

Change `{spec_file}` status to `in-review` in the frontmatter before continuing.

### Construct Diff

Read `{baseline_commit}` from `{spec_file}` frontmatter. If `{baseline_commit}` is missing or `NO_VCS`, use best effort to determine what changed. Otherwise, construct `{diff_output}` covering all changes — tracked and untracked — since `{baseline_commit}`.

Do NOT `git add` anything during diff construction — this is read-only inspection.

### Review

Launch three subagents without conversation context. If no sub-agents are available, generate three review prompt files in `{implementation_artifacts}` — one per reviewer role below — and HALT. Ask the human to run each in a separate session, ideally a different LLM, and paste back the findings.

- Blind hunter — receives `{diff_output}` only. No spec, no context docs, no project access. Invoke via the `bmad-review-adversarial-general` skill.
- Edge case hunter — receives `{diff_output}` and read access to the project. Invoke via the `bmad-review-edge-case-hunter` skill.
- Acceptance auditor — receives `{diff_output}`, `{spec_file}`, and read access to the project. Must also read the docs listed in `{spec_file}` frontmatter `context`. Checks for violations of acceptance criteria, rules, and principles from the spec and context docs.

### Classify

1. Deduplicate all review findings.
2. Classify each finding:
   - `intent_gap` — caused by the change; cannot be resolved from the spec because the captured intent is incomplete.
   - `bad_spec` — caused by the change; the spec should have prevented it.
   - `patch` — caused by the change; trivially fixable without human input.
   - `defer` — pre-existing issue not caused by this story.
   - `reject` — noise.
3. Process findings in cascading order. If intent_gap or bad_spec findings exist, they trigger a loopback. If neither exists, process patch and defer normally. Increment `{specLoopIteration}` on each loopback. If it exceeds 5, HALT and escalate to the human.
   - `intent_gap`: Revert code changes. Loop back to the human to resolve the frozen intent. Once resolved, read fully and follow `./step-02-plan.md`.
   - `bad_spec`: Revert code changes after extracting KEEP instructions. Amend non-frozen spec sections, append to `## Spec Change Log`, then read fully and follow `./step-03-implement.md`.
   - `patch`: Auto-fix and commit locally if version control is available.
   - `defer`: Append to `{deferred_work_file}`.
   - `reject`: Drop silently.

## NEXT

Read fully and follow `./step-05-present.md`.
