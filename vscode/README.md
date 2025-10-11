# VS Code Configuration

This folder contains version-controlled VS Code settings.

## Files

- `settings.json` - Editor and workspace settings
- `keybindings.json` - Custom keyboard shortcuts
- `snippets/` - Code snippets for various languages

## Setup

To use these settings on a new machine:

1. **Close VS Code** (important!)
2. **Run the setup script as Administrator**:
   ```powershell
   # From the .config directory
   .\setup-vscode-symlink.ps1
   ```

This will create a junction (symlink) from `%APPDATA%\Code\User` to this folder.

## Key Settings

- **Font**: JetBrainsMono Nerd Font
- **Font Size**: 14
- **Font Ligatures**: Enabled
- **Format on Save**: Enabled for modifications only
- **Render Whitespace**: All
- **Cursor Surrounding Lines**: 10

## Manual Setup (Alternative)

If you prefer not to use symlinks:

```powershell
# Copy settings to VS Code User folder
Copy-Item .\vscode\settings.json $env:APPDATA\Code\User\settings.json
Copy-Item .\vscode\keybindings.json $env:APPDATA\Code\User\keybindings.json
Copy-Item .\vscode\snippets $env:APPDATA\Code\User\snippets -Recurse
```

## Syncing Changes

After making changes in VS Code, copy them back to the repo:

```powershell
# Manual sync (if not using symlinks)
Copy-Item $env:APPDATA\Code\User\settings.json .\vscode\settings.json
Copy-Item $env:APPDATA\Code\User\keybindings.json .\vscode\keybindings.json
```

With symlinks, changes are automatically reflected in the repo!
