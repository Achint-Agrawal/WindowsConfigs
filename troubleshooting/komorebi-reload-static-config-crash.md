# Komorebi Crashes on `ReloadStaticConfiguration`

## Symptom

Komorebi exits silently shortly after editing a profile JSON and triggering an
in-place reload (e.g. `Alt+Shift+R` or `komorebic reload-configuration`). Windows
Event Viewer (`Application` log) records an `APPCRASH` / `BEX64` for
`komorebi.exe` with exception code `0xc0000005` (access violation) and faulting
module `unknown`:

```text
Faulting application name: komorebi.exe, version: 0.0.0.0
Exception code: 0xc0000005
Faulting module path: unknown
```

The plaintext log at `%TEMP%\komorebi_plaintext.log.<date>` shows the crash
happens during a `ReloadStaticConfiguration` call, often the second of two
reloads fired in quick succession:

```text
INFO process_command{ReloadStaticConfiguration(...)}: ... reloading static configuration
INFO ... border_manager: purging known borders: [...]
INFO ... static_config: loading applications.json from: ...
INFO process_command{ReloadStaticConfiguration(...)}: processed
INFO process_command{ReloadStaticConfiguration(...)}: ... reloading static configuration
<EOF — process terminated>
```

After the crash, `komorebi` is gone but `whkd` and `yasb` keep running, so
hotkeys still fire but no window tiling happens.

## Root Cause

`komorebic reload-configuration` performs an in-place reload of the running
window manager. When the new config changes workspace counts or
`initial_workspace_rules` while windows are still mapped to the old workspace
layout, komorebi can hit an access violation in its window/border tracking
state. Rapid back-to-back reloads (e.g. accidental double `Alt+Shift+R`) make it
much more likely.

Observed in komorebi `v0.1.38` on Windows 11. Tracked upstream as one of several
reload-related crashes (see
[LGUG2Z/komorebi#1454](https://github.com/LGUG2Z/komorebi/issues/1454) and
related issues).

## Fix

Restart komorebi with the active profile using the switch script — it does a
full stop → start cycle, which is the reliable path:

```powershell
.\komorebi\switch-komorebi.ps1 default   # or whichever profile was active
```

If you do not know which profile was active, inspect `komorebi/komorebi.json`
(it is a copy of the last switched-to profile) and match it against the
`komorebi.*.json` files.

## Prevention

- Prefer `switch-komorebi.ps1 <profile>` over `Alt+Shift+R` after editing a
  profile JSON, especially when changing `initial_workspace_rules` or workspace
  counts. The switch script stops komorebi cleanly before reapplying config.
- Avoid pressing the reload hotkey multiple times in quick succession.
- If you must use in-place reload, save the file, wait a second, then trigger
  reload exactly once.
