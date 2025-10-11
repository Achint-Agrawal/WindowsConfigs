# YASB Autostart Options

You have two supported ways to start YASB automatically at login while using komorebi + whkd (without the komorebi built-in bar).

## 1. Scheduled Task (Recommended)
Creates a logon task that starts YASB reliably even if Explorer restarts.

Run once in PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File "$Env:USERPROFILE\.config\yasb\autostart-yasb.ps1" -RegisterTask
```
Recreate (force) if you changed the install path:
```powershell
powershell -ExecutionPolicy Bypass -File "$Env:USERPROFILE\.config\yasb\autostart-yasb.ps1" -RegisterTask -Force
```
Remove it later:
```powershell
Unregister-ScheduledTask -TaskName "YASB Autostart" -Confirm:$false
```

## 2. Startup Folder Shortcut
Simpler, but Explorer must be running.
```powershell
powershell -ExecutionPolicy Bypass -File "$Env:USERPROFILE\.config\yasb\autostart-yasb.ps1" -CreateStartupShortcut
```
Overwrite existing shortcut:
```powershell
powershell -ExecutionPolicy Bypass -File "$Env:USERPROFILE\.config\yasb\autostart-yasb.ps1" -CreateStartupShortcut -Force
```
Remove manually by deleting `YASB.lnk` from:
```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup
```

## 3. (Optional) PowerShell Profile Fallback
If you always start a PowerShell session early:
```powershell
# Add to $PROFILE
if (-not (Get-Process yasb -ErrorAction SilentlyContinue)) {
  $p = 'C:\\Program Files\\YASB\\yasb.exe'
  if (Test-Path $p) { Start-Process $p }
}
```

## Verification
After login, run:
```powershell
Get-Process yasb -ErrorAction SilentlyContinue | Select ProcessName, StartTime
```
You should see a `yasb` process present.

## Keeping Single-Bar Setup
- Do not reintroduce `--bar` in any `komorebic` start commands.
- `switch-komorebi.ps1` already enforces this and can optionally launch YASB if missing.
- `whkdrc` restart bindings now use `komorebic stop --whkd; komorebic start --whkd`.

## Updating YASB Path
If YASB installs to a different directory, update `autostart-yasb.ps1` (`$yasbExe`) and re-run with `-Force`.

## Uninstall / Disable
- Scheduled Task: `Unregister-ScheduledTask -TaskName "YASB Autostart" -Confirm:$false`
- Shortcut: Delete the `.lnk` file.
- Script: Remove the two new files if you no longer need them.

Happy tiling!
