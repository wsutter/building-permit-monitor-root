---
---

# Step 5: Present

## RULES

- YOU MUST ALWAYS SPEAK OUTPUT in your Agent communication style with the config `{communication_language}`.
- Never push, merge, delete branches, or create pull requests without explicit human confirmation.
- The final state of this workflow is a review-ready feature branch, not an automatic merge.

## INSTRUCTIONS

### Final Local Validation

1. Run formatting/check commands only when they exist in the repository.
   - For Java/Maven modules, prefer `mvn -B verify`.
   - Run `mvn spotless:apply` only if the project declares Spotless.
2. If formatting changes files, commit them locally with:
   - `Style: {story-key-or-slug} - Apply code formatting`
3. Do not push automatically.

### Git Flow: Human Handoff

Prepare, but do not execute, the Git Flow commands the human may want next:

```bash
git push -u origin {branch_name}
# open PR: {branch_name} -> develop
# after approval, squash-merge via GitHub UI or locally
```

If the repository has no `develop` branch, target `main` instead and say so explicitly.

### Generate Suggested Review Order

Read `{baseline_commit}` from `{spec_file}` frontmatter and construct the diff of all changes since that commit.

Append the review order as a `## Suggested Review Order` section to `{spec_file}` after the last existing section. Do not modify the Code Map.

Build the trail as an ordered sequence of stops — clickable `path:line` references with brief framing — optimized for a human reviewer reading top-down to understand the change:

1. Order by concern, not by file.
2. Lead with the entry point.
3. Inside each concern, order stops from most important to supporting.
4. End with tests, config, types, and other supporting changes.
5. Every code reference is a clickable spec-file-relative link with `#L` line anchors.
6. Each stop gets one ultra-concise line of framing, no more than 15 words.

Format each stop as framing first, link on the next indented line:

```markdown
## Suggested Review Order

**{Concern name}**

- {one-line framing}
  [`file.ts:42`](../../src/path/to/file.ts#L42)
```

When there is only one concern, omit the bold concern label.

### Mark Spec Done

Change `{spec_file}` status to `done` in the frontmatter.

Follow `./sync-sprint-status.md` with `{target_status}` = `in-review`.

### Commit and Open

1. If version control is available and the tree is dirty, create a local commit with a conventional message derived from the spec title.
2. Open the spec in the user's editor so they can click through the Suggested Review Order:
   - Resolve two absolute paths: the repository root and `{spec_file}`.
   - Run `code -r "{absolute-root}" "{absolute-spec-file}"`.
   - If `code` is not available, skip gracefully and tell the user the spec file path instead.

### Display Summary

Display summary of your work to the user, including the commit hash if one was created. Any file paths shown in conversation/terminal output must use CWD-relative format with `:line` notation and no leading `/`. Include:

- A note that the spec is open in their editor, or the file path if it could not be opened.
- Mention that `{spec_file}` now contains a Suggested Review Order.
- Navigation tip: "Ctrl+click (Cmd+click on macOS) the links in the Suggested Review Order to jump to each stop."
- The exact suggested Git Flow next commands, but do not run them.

Workflow complete. HALT and wait for human input.

## On Complete

Run: `python3 {project-root}/_bmad/scripts/resolve_customization.py --skill {skill-root} --key workflow.on_complete`

If the resolved `workflow.on_complete` is non-empty, follow it as the final terminal instruction before exiting.
