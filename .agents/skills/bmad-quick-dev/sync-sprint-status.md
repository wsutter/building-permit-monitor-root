# Sync Sprint Status

Shared sub-step for updating `sprint-status.yaml` during quick-dev. Called from any route with a `{target_status}` parameter.

## Preconditions

Skip this entire file and return to caller if ANY of:
- `{story_key}` is unset
- `{sprint_status}` does not exist on disk

## Instructions

1. Load the FULL `{sprint_status}` file.
2. Find the `development_status` entry matching `{story_key}`. If not found, warn the user once (`"{story_key} not found in sprint-status; skipping sprint sync"`) and return to caller.
3. Use this status order: `backlog` < `in-progress` < `in-review` < `done`.
4. Idempotency check: if `development_status[{story_key}]` is already at `{target_status}` or a later state, return to caller. Never regress a story's status.
5. Set `development_status[{story_key}]` to `{target_status}`.
6. Epic lift only when `{target_status}` = `in-progress`: derive the parent epic key as `epic-{N}` from the leading numeric segment of `{story_key}`. If that entry exists and is `backlog`, set it to `in-progress`.
7. Refresh `last_updated` to the current date.
8. Save the file, preserving all comments and structure including STATUS DEFINITIONS and WORKFLOW NOTES.
