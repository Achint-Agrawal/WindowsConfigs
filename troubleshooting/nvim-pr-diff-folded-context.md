# PR diffs show only fragments of a file

## Symptom

An ADO PR review shows changed sections with little surrounding context,
and keyboard focus remains in the file list rather than the diff.

## Root cause

Diffview loads the complete files, but its default `view.foldlevel = 0`
collapses unchanged regions in side-by-side layouts. Its default
`view.default.focus_diff = false` leaves initial keyboard focus in the file
panel. The first-change cursor positioning already works; the diff pane
simply does not have focus.

## Fix

The Diffview dependency in `nvim\lua\plugins\ado-pr.lua` sets:

- `view.foldlevel = 99` to keep unchanged context expanded.
- `view.default.focus_diff = true` to focus the diff on opening a review.

Diffview's existing first-change navigation handles both side-by-side and
inline layouts. Newly opened files start at their first change; revisiting
a file preserves its previous cursor position. No extra cursor hooks or
navigation overrides are needed. Reviews default to inline/unified diffs;
`<leader>gv` toggles inline and side-by-side from the diff pane or file list.
Both layouts keep unchanged context expanded. These settings also apply
to ordinary Diffview diffs, not only ADO reviews.

Restart Neovim and reopen the review to apply the configuration.
For an already open diff, focus a diff pane with `Ctrl+w`, then `h` or `l`,
and use `zR` to expand its folds. This reveals the existing full-file content
without fetching anything or changing the diff base.

## Prevention

- Keep the full-file fold setting when changing Diffview layouts.
- Use `Tab` / `Shift+Tab` to move between changed files and `]c` / `[c`
  between changes.
- Use `<leader>e` to focus the file list explicitly.
- Distinguish collapsed context from a truncated file before changing Git
  diff options or adding custom navigation hooks.
