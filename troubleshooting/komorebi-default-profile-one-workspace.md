# Default Komorebi Profile Shows Too Few Workspaces

## Symptom

After pressing `Alt+Ctrl+D`, YASB shows only workspace `I`, or only `I` through
`III`, instead of workspaces `I` through `X`. The active JSON can contain all
ten workspaces while `komorebic state` reports fewer.

## Root Cause

There are two distinct causes:

- The original `komorebi.default.json` pinned monitor index `0` to a specific
`Default_Monitor` device ID. That ID changes when the VM display is recreated
or its virtual display adapter changes. Komorebi could not match the configured
monitor to the current display, so it created only its fallback workspace.
- Komorebi can restore `%TEMP%\komorebi.state.json` **after** loading the static
configuration. In the three-workspace case, the startup log explicitly showed
`applying state from ... komorebi.state.json`, and that file contained only
`I` through `III`. Restoring it resized the configured workspaces back to three.
The switcher's subsequent `workspace-name` commands could rename existing
workspaces but could not create missing ones. YASB was displaying the actual
daemon state, not hiding empty workspaces.

## Fix

The default single-monitor VM profile no longer sets
`display_index_preferences`. Komorebi applies its sole monitor configuration to
the connected display by index, regardless of the VM's current device ID.

`switch-komorebi.ps1` also starts Komorebi with `--clean-state`, so an explicit
profile switch uses the selected profile rather than the previous session's
saved workspace layout. It does not delete the saved state file or change
ordinary non-profile startup.

Run the profile switch again:

```powershell
.\komorebi\switch-komorebi.ps1 default
```

For the three-workspace case, recover without restarting or moving existing
windows by creating the missing workspaces and applying the configured names:

```powershell
komorebic ensure-workspaces 0 10
$config = Get-Content .\komorebi\komorebi.default.json -Raw | ConvertFrom-Json
for ($w = 0; $w -lt $config.monitors[0].workspaces.Count; $w++) {
    komorebic workspace-name 0 $w $config.monitors[0].workspaces[$w].name
}
```

YASB updates from Komorebi's workspace events; no bar configuration change is
needed. Use this monitor-0 recovery only for the single-monitor default profile.

## Prevention

Do not pin `Default_Monitor` device IDs in single-monitor VM profiles. Keep
`display_index_preferences` only for multi-monitor profiles where stable
physical monitor IDs are needed to preserve ordering.

Keep `--clean-state` on profile-switch startup so saved state cannot override
workspace counts, names, or layouts. A profile switch intentionally reapplies
the selected profile instead of preserving the previous session's arrangement.
Run the launch regression without restarting any applications:

```powershell
.\komorebi\tests\profile-start.ps1
```

For live verification, compare the count and names in `komorebic state` with
the selected profile; editing the JSON alone does not prove it was applied.
