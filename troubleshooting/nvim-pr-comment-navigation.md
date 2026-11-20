# A PR-wide comment list with exact source navigation

## Symptom

`F7` only lists threads covering the current line. `]t` / `[t` only navigate
the displayed file, so discussions elsewhere in the PR are easy to miss.
Old-side comment positions cannot be used directly as inline-buffer rows.

## Root cause

The pinned ADO plugin's follower pane is cursor/file scoped. Its shared
resolved-thread collection omits PR-level comments entirely.
Inline layouts display old deleted lines as virtual text; those lines have
no cursor position in the new buffer. Historical comments can also refer
to files or lines absent from the current comparison.

## Fix

`nvim\lua\config\ado-comments.lua`, wired in
`nvim\lua\plugins\ado-pr.lua`, provides:

| Key/command | Action |
| --- | --- |
| `<leader>gC` / `:AdoPrComments` | Refresh/search all comments and replies |
| Enter in the picker | Open the selected comment's source and text |
| `]T` / `[T` | Next/previous comment across the PR, with wraparound |
| `:AdoPrNextComment` / `:AdoPrPrevComment` | Equivalent navigation commands |
| `q` in a commit snapshot | Close the snapshot and return to the review |

Resolved threads and PR-level/file-level discussions remain in the list;
deleted comments and system activity do not. Comments are ordered by path,
line, thread, and reply. The preview preserves multiline bodies.

Right-side comments use the current diff's new buffer. Left-side comments
switch to side-by-side and focus the old buffer. Renames match the old path.
Unchanged files use read-only commit snapshots, never the working-tree file.
Missing/out-of-range anchors resolve through ADO's original tracking data;
if that data is unavailable, an explicit error replaces a misleading jump.
PR-level comments have no source target.
Snapshot buffers are review-scoped and escape filename percent signs in
their winbars, so filenames are displayed literally.

Returning from a snapshot can overlap Diffview's file-refresh and buffer-load
events. The hunk-review refresh now waits until its displayed buffers are
loaded, and hunk actions reject in-flight swaps.

Restart Neovim and reopen the PR to load the commands and shortcuts.

## Prevention

- Use uppercase `]T` / `[T` for all comments; lowercase `]t` / `[t` retain
  the native current-file behavior.
- Reopen the comments picker to fetch new comments or after changing the
  PR/iteration. Old selections cannot navigate a different review scope.
- Keep left/right revision handling explicit; never clamp a stale anchor to
  a nearby line or read an unchanged file from a potentially modified checkout.
- Run `nvim\tests\ado-comments.lua` when changing this integration. It checks
  the real picker, cross-file/side jumps, replies, resolved comments, renames,
  deletions, immutable/historical snapshots, iteration scoping, and stale/error
  handling without writing to ADO.
- Rerun `nvim\tests\diffview-review.lua` when changing shared Diffview hooks.
