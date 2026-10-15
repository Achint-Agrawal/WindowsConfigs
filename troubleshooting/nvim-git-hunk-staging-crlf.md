# Neovim Git hunk staging fails for CRLF files

## Symptom

Pressing Tab in the Git diff picker's search box fails with
`git apply --cached`, `patch failed`, and `patch does not apply`.
The file's current diff looks correct in the preview.

## Root cause

The installed Snacks line-oriented process reader removes the carriage
return before each newline. Its default Git diff finder uses that reader,
then reconstructs individual patches from the normalized lines.

That changes the patch content for files stored with CRLF line endings
in Git's index. Files marked `-text` in `.gitattributes` can retain CRLF
in the index even when `core.autocrlf=true`. Git correctly rejects the
LF-only reconstructed patch because its context no longer matches.

For the reported SQL file, `git ls-files --eol` showed
`i/crlf w/crlf attr/-text`. A read-only `git apply --cached --check` accepted
the raw diff but rejected the same diff after CRLF-to-LF normalization.

## Fix

`nvim\lua\plugins\git-diff-filter.lua` captures Git's diff output in raw
chunks and passes it to Snacks' existing diff parser. Individual hunks
retain their original carriage returns, including mixed line endings and
missing-final-newline markers.

Snacks' normal stage/unstage actions still apply only the selected hunks.
The preview uses a separate normalized copy for display; it does not
change the patch, index, or source file.

Restart Neovim and reopen the picker before trying Tab again. Already-open
pickers still contain their old normalized patches.

## Prevention

- Preserve raw patch bytes before parsing or splitting into hunks.
- Normalize only the display copy, not the patch sent to Git.
- Do not add whitespace-ignore flags or change repository line-ending
  settings to hide this mismatch.
- Exercise stage/unstage round trips for CRLF, LF, mixed endings, and
  files without a final newline.
- If a file changes after opening the picker, refresh or reopen it before
  staging; stale patches can also legitimately fail to apply.
