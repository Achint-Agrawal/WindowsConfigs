# Mixed line endings cause false diagnostics and Git diffs

## Symptom

An unmodified buffer shows thousands of StyleCop documentation/blank-line
errors and `^M` markers. GitSigns marks most of the file as changed while
LazyGit or `git diff --numstat` shows only the intended insertion.

The errors/warnings-only diagnostic filter is still active: these false
diagnostics are being reported as errors.

## Root cause

The file already contains both CRLF and LF endings, including in the Git
index. Neovim reads it with `fileformat=unix`, retaining a trailing CR
character on each CRLF line so the original bytes can be preserved.

The built-in EditorConfig `end_of_line=crlf` handler then changes
`fileformat` to `dos` without removing those retained CR characters.
Roslyn's LSP document and GitSigns serialize each line using CRLF, producing
CRCRLF on lines that already contain CR. Their text therefore differs from
the actual file on disk. A write in that state could also corrupt its endings.

## Fix

`nvim\lua\config\line-endings.lua` wraps the built-in EditorConfig newline
property before initial files load. When a CRLF request would change an
LF-read buffer containing retained trailing CR characters, the guard keeps
the detected representation and emits one warning per file per session.
It does not edit buffer content or rewrite the file.

Other EditorConfig properties still apply. Pure-LF files still honor the
project's requested CRLF conversion; pure-CRLF and new files keep their normal
behavior. An unchanged save of a mixed-ending file preserves its existing
line endings rather than normalizing the whole file.

For an already-open affected session, do not save just to refresh the diff.
Preserve any unsaved work separately, restart Neovim to load the guard, and
reopen the file from disk. Reloading sends Roslyn a fresh document and lets
GitSigns recalculate its hunks. Do not force-reload a modified buffer.

The observed 14-line insertion then appeared as one GitSigns hunk with
14 additions and no removals. The thousands of false StyleCop errors
disappeared; the remaining existing analyzer error was not suppressed.

## Prevention

- Keep the guard initialized in `nvim\lua\config\options.lua`, before file
  reading and EditorConfig application.
- Compare LSP/GitSigns serialized bytes with disk, not just buffer text or
  diagnostic counts.
- Do not hide analyzer errors, ignore all whitespace in diffs, or normalize
  an entire source file to conceal a buffer-representation bug.
- Treat intentional project-wide newline normalization as a separate change.

`nvim\tests\mixed-line-endings.lua` exercises real EditorConfig, LSP text,
GitSigns/Git hunk agreement, unchanged saves, normal newline policies,
repeat application, and genuine compiler-error visibility.
