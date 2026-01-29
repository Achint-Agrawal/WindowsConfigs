# Copilot Instructions

This is a Windows dotfiles repository containing configuration for development tools and a tiling window manager setup.

## Repository Structure

- **`setup-windows.ps1`** - Main idempotent setup script that configures a fresh Windows machine
- **`komorebi/`** - Tiling window manager configs (multiple profiles for different monitor setups)
- **`whkdrc`** - Hotkey daemon config for Komorebi keyboard shortcuts
- **`yasb/`** - Status bar (Yet Another Status Bar) config
- **`wezterm/`** - Terminal emulator config (Lua)
- **`nvim/`** - Neovim config (LazyVim-based)
- **`vscode/`** - VS Code settings (symlinked to `%APPDATA%\Code\User`)
- **`ohmyposh/`** - PowerShell prompt theme

## Key Conventions

### Komorebi Profiles
Multiple Komorebi configs exist for different environments (`komorebi.home.json`, `komorebi.laptop.json`, etc.). The active config is controlled via:
- `switch-komorebi.ps1 <profile>` - Switches profile and restarts services
- `komorebi.json` is a symlink to the active profile (gitignored)
- Profiles are switched via whkd shortcuts: `Alt+Ctrl+H` (home), `Alt+Ctrl+L` (laptop), etc.

### Symlink Strategy
Configs are symlinked from this repo to their expected locations:
- VS Code: `%APPDATA%\Code\User` → `~/.config/vscode` (junction)
- WezTerm: `~/.wezterm.lua` → `~/.config/wezterm/wezterm.lua` (symlink)
- whkdrc: Already at `~/.config/whkdrc` (expected location)
- YASB: Already at `~/.config/yasb` (expected location)

### Environment Variables
- `KOMOREBI_CONFIG_HOME` must point to `~/.config/komorebi`

### Keyboard Shortcuts (whkdrc)
Uses vim-style navigation throughout:
- `Alt+H/J/K/L` - Focus windows (left/down/up/right)
- `Alt+Shift+H/J/K/L` - Move windows
- `Alt+1-0` - Switch to workspace I-X
- `Alt+Shift+1-0` - Move window to workspace

### Font Requirement
All terminal apps use **JetBrainsMono Nerd Font** for icon support.

## Making Changes

When modifying configs:
1. Edit files directly in this repo (symlinks make changes live)
2. For Komorebi changes, run `komorebic reload-configuration` or `Alt+Shift+R`
3. For YASB, restart the service or modify with `watch_config: true` enabled
4. Test PowerShell scripts with `-WhatIf` when available
