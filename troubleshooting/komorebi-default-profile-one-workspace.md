# Default Komorebi Profile Shows One Workspace

## Symptom

After pressing `Alt+Ctrl+D`, YASB shows only workspace `I` instead of
workspaces `I` through `X`.

## Root Cause

`komorebi.default.json` pinned monitor index `0` to a specific
`Default_Monitor` device ID. That ID changes when the VM display is recreated
or its virtual display adapter changes. Komorebi could not match the configured
monitor to the current display, so it created only its fallback workspace.

## Fix

The default single-monitor VM profile no longer sets
`display_index_preferences`. Komorebi applies its sole monitor configuration to
the connected display by index, regardless of the VM's current device ID.

Run the profile switch again:

```powershell
.\komorebi\switch-komorebi.ps1 default
```

## Prevention

Do not pin `Default_Monitor` device IDs in single-monitor VM profiles. Keep
`display_index_preferences` only for multi-monitor profiles where stable
physical monitor IDs are needed to preserve ordering.
