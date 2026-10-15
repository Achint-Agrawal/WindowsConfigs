# LazyGit opens an external application instead of Neovim

## Symptom

Pressing `o` on a file in Neovim's LazyGit terminal opens an external
application or the Windows application chooser instead of editing the file
in Neovim.

## Root cause

LazyGit binds `o` to `openFile`, not its editor action (`e`). On Windows,
`openFile` defaults to `start "" {{filename}}`, which uses the file's
Windows association.

Snacks configures LazyGit's `nvim-remote` editor preset, but that does not
override the separate `os.open` command. LazyGit 0.60.0's preset also uses
POSIX shell syntax while LazyGit executes Windows commands through `cmd /c`.
The preset's `--remote-tab` would open an additional editor tab.

## Fix

`nvim\lua\plugins\snacks-lazygit.lua` overrides the Windows commands for
opening files, editing files/diff lines, and opening directories.
The commands invoke `nvim\lazygit-open.lua` with a headless Neovim client.
The helper uses the terminal's `NVIM` server address and passes filenames
as RPC arguments, rather than interpolating them into editor commands.
It returns to the previous editor window, opens the file with `:drop`,
positions the cursor, and then quits LazyGit.

LazyGit's Windows command builder caret-escapes metacharacters even inside
quoted filenames. The helper reverses that escaping before opening paths,
so spaces, ampersands, literal carets, and percent signs remain intact.

Opening and positioning happen in one RPC request. Quitting LazyGit first
can terminate the client before it reaches a separate cursor-positioning
command. A headless client also avoids starting Neovim's terminal UI.

Both `o` and `e` open files in Neovim; diff editing retains the selected
line. The override is part of Snacks' generated LazyGit configuration, so
standalone LazyGit is not changed.

Restart Neovim after changing the configuration and reopen LazyGit.

## Prevention

- Keep `os.open` configured as well as the editor commands.
- Avoid POSIX shell syntax and shell command chains on Windows.
- Use a headless RPC client and `:drop` rather than `--remote-tab`.
- Set the cursor before quitting LazyGit.
- Do not edit Snacks' generated `lazygit-theme.yml`; it is rebuilt from
  the Neovim configuration.
