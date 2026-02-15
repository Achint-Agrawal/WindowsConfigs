# Copilot Instructions

Windows dotfiles repo — tiling WM setup, terminal configs, and editor settings all managed via symlinks from `~/.config`.

## Architecture

**Config-as-symlinks:** All configs live in this repo and are symlinked to their expected system locations. Edits here take effect immediately. `setup-windows.ps1` is the idempotent bootstrap script that installs tools (via Scoop/winget), creates symlinks, and registers autostart tasks.

**Komorebi multi-profile system:** Each `komorebi/komorebi.<profile>.json` defines a complete monitor/workspace layout for a specific environment (home, laptop, office, etc.). `switch-komorebi.ps1 <profile>` stops YASB → restarts komorebi with the new config → re-applies workspace names (race condition fix) → restarts YASB. The `ValidateSet` in that script must be updated when adding new profiles. `komorebi.json` is a gitignored symlink to the active profile. `applications.json` holds per-app tiling rules shared across all profiles.

**Neovim:** LazyVim-based config. Custom plugins go in `nvim/lua/plugins/`. Uses Lazy.nvim for plugin management with `lazy-lock.json` tracked for reproducibility.

## Key Conventions

- **Vim-style keybindings everywhere:** `hjkl` navigation in whkdrc (`Alt+`), WezTerm (`Ctrl+` for panes, `Alt+` for resize), and Neovim.
- **JetBrainsMono Nerd Font** is the universal font across WezTerm, VS Code, Oh My Posh, and YASB.
- **Workspace naming:** Roman numerals I–X across all Komorebi profiles and YASB bar labels.
- **BSP layout** (Binary Space Partitioning) is the default for all Komorebi workspaces.
- **Profile switching shortcuts** in whkdrc: `Alt+Ctrl+G` (ghar), `Alt+Ctrl+L` (laptop), `Alt+Ctrl+H` (home), `Alt+Ctrl+O` (office).

## Symlink Map

| System Location | Repo Path | Type |
|---|---|---|
| `%APPDATA%\Code\User` | `vscode/` | junction |
| `~/.wezterm.lua` | `wezterm/wezterm.lua` | symlink |
| `~/.config/whkdrc` | `whkdrc` | in-place |
| `~/.config/yasb` | `yasb/` | in-place |
| `$KOMOREBI_CONFIG_HOME` | `komorebi/` | env var |

## Making Changes

- **Komorebi:** `komorebic reload-configuration` or `Alt+Shift+R` after editing profiles.
- **YASB:** Restart the process, or rely on `watch_config: true` if enabled.
- **VS Code:** Changes via the junction are live in both directions.
- **PowerShell scripts:** Use `-WhatIf` when available to test before running.
- **New Komorebi profile:** Create `komorebi/komorebi.<name>.json`, add `<name>` to the `ValidateSet` in `switch-komorebi.ps1`, and add a whkd shortcut in `whkdrc`.
