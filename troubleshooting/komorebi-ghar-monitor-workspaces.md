# Ghar Workspaces Appear on the Wrong Monitor

## Symptom

After pressing `Ctrl+Alt+G`, workspaces can appear on the wrong screen, or the
external monitor can retain all ten workspaces while the laptop shows only
`VI`, instead of the intended split:

- External monitor: `I`, `II`, `III`, `IV`, `V`.
- Laptop screen: `VI`, `VII`, `VIII`, `IX`, `X`.

## Root Cause

The `ghar` profile pinned the external ABM0215 monitor to an outdated Windows
device ID, `ABM0215-4&4ff745d&0&UID4145`. The connected monitor now reports
`ABM0215-5&2625a9eb&0&UID281`, so Komorebi could not match it to its configured
workspace layout. Windows' primary-display setting is independent of
Komorebi's workspace assignment.

Even after correcting the monitor identifier, the profile switcher started
Komorebi without `--clean-state`. Komorebi loads the selected configuration,
then reapplies `%TEMP%\komorebi.state.json` from its previous shutdown. That
saved state retained ten workspaces on the external monitor and only one on
the laptop, overriding the profile's five-per-monitor layout. Reapplying
workspace names did not remove the extra workspaces or restore the missing ones.

The switcher also replaced the active configuration before stopping Komorebi,
allowing its file watcher to reload the configuration during the transition.

## Fix

`komorebi/komorebi.ghar.json` now identifies the external monitor by its
reported serial number, `00000021`, at configuration index `0`. Komorebi
accepts either a serial number or a device ID in `display_index_preferences`.
The laptop remains at index `1` using its device ID because its reported serial
number, `0`, is not a unique hardware identifier.

`switch-komorebi.ps1` now waits for Komorebi to stop before copying the selected
profile to the active configuration. It starts with an explicit `--config`
path and `--clean-state`, so previous runtime state cannot override the
selected profile. Startup and workspace-naming failures are reported instead
of being ignored. The script also preserves YASB customizations rather than
resetting its configuration through Git.

Reapply the profile with `Ctrl+Alt+G`:

```powershell
.\komorebi\switch-komorebi.ps1 ghar
```

A clean profile switch intentionally discards the previous workspace
arrangement and reapplies the selected profile's layout and application rules.

## Prevention

Use a stable, unique monitor serial number when available, rather than a
Windows device ID that can change with the display connection. Keep serial
numbers as JSON strings so leading zeroes are preserved.

Keep `--clean-state` when switching profiles, and stop Komorebi before
replacing its active configuration. A restart without that flag is not enough
to reset a layout stored in its dumped runtime state.

Compare `komorebic monitor-information` with `display_index_preferences` after
changing connections. Inspect `komorebic state` to confirm all five workspace
names on each physical display; Windows' primary-display setting alone does
not determine Komorebi's workspace assignment.
