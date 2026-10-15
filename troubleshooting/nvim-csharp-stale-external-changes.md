# Neovim C# reports a missing member that builds successfully

## Symptom

Roslyn reports `CS1061` for a member that exists in the current checkout
and compiles successfully. Go-to-definition resolves the containing class
to the correct source file, but cannot find the newly added member.

This can happen after another editor, process, or Git operation changes a
C# source file that is not open in Neovim.

## Root cause

The installed Neovim 0.12 Windows file watcher mishandles relative LSP
watch patterns. In `vim\lsp\_watchfiles.lua`, the relative pattern is
prefixed with the unnormalized directory returned by `vim.uri_to_fname`,
which uses backslashes on Windows.

`vim\_watch.lua` normalizes file-event paths to forward slashes. Those
paths no longer match the backslash-prefixed pattern, so the event is
discarded before Roslyn receives `workspace/didChangeWatchedFiles`.
Roslyn can therefore retain an older source snapshot despite the newer
file being present on disk.

## Fix

`nvim\lua\plugins\dotnet.lua` disables the client capability
`workspace.didChangeWatchedFiles.dynamicRegistration` for Roslyn on Windows.
Roslyn then uses its native file-system watcher rather than delegating
watching to Neovim.

This change affects only Roslyn on Windows. Source synchronization for
open buffers, compiler diagnostics, analyzers, and navigation remain
enabled. No diagnostic codes are suppressed, and no source project or
build settings are changed.

Restart Neovim to start Roslyn with the corrected capability and reload
the current source snapshot.

## Prevention

- Distinguish stale workspace data from genuine source/compiler errors.
- Compare the definition location with the current checkout before
  changing project references.
- Keep native Roslyn watching enabled while this Windows path mismatch
  is present; do not disable file-change handling entirely.
- Verify external changes to an unopened dependency are reflected in
  diagnostics and go-to-definition, not just the initial solution load.
