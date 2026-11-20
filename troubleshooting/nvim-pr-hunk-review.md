# Reviewing individual PR hunks

## Symptom

Diffview's file-list `w` marks an entire file, not an individual hunk.
There is no built-in persistent hunk checklist or navigation that skips
reviewed hunks.

## Root cause

Diffview's selections API tracks files. Its ordinary change navigation
does not know which hunks have been reviewed. Linematch can also split
changes into multiple sub-hunks sharing a cursor anchor, which makes
independent cursor-based marks ambiguous.

## Fix

`nvim\lua\config\diffview-review.lua` adds review-local metadata and keys
through the Diffview configuration in `nvim\lua\plugins\ado-pr.lua`:

| Key | Action |
| --- | --- |
| `<leader>ghw` | Toggle the hunk under the cursor reviewed/unreviewed |
| `]r` / `[r` | Jump to the next/previous unreviewed text hunk |
| `w` in the file list | Mark/unmark a whole file and its hunks |
| `H` in the file list | Hide/show reviewed files |

The module combines overlapping cursor groups, shares marks between inline
and side-by-side layouts, and selects a file when all its text hunks are
reviewed. Unreviewing one hunk unselects the file. Navigation includes
hidden files, wraps across files, and skips binary/non-text changes.
Review those changes manually at file level.

Progress is saved under `stdpath("state")\diffview-hunk-review`. Only
completion metadata is stored. It is local to the checkout, resolved
old/new commit pair, and diff options; it does not update ADO review status.
Working-tree/index and merge-conflict views do not use hunk tracking.
Restart Neovim and reopen the PR to load the new configuration.

## Prevention

- Use `]r` rather than `]c` when looking specifically for unreviewed work.
- Expect a new iteration, base, or diff option set to start unreviewed.
  Reopen the exact previous comparison to restore its saved progress.
- Keep native file selections synchronized with hunk progress when changing
  review hooks. File selections also control Diffview's bulk operations.
- Do not disable error notifications for unreadable or invalid progress.
  Corrupted metadata is reported and is not overwritten.
- Run `nvim\tests\diffview-review.lua` against a fresh fixture directory
  when changing the integration. Its `write`, `reload`, and `guard` phases
  cover navigation, separate-process persistence, marker cleanup, corrupt
  state, and rejection of mutable comparisons.
