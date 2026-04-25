# Komorebi Troubleshooting

## `komorebic start` fails: "komorebi.exe did not start... Trying again"

### Symptom

Running `komorebic start --whkd` (or via `switch-komorebi.ps1`) loops with:

```
Waiting for komorebi.exe to start...komorebi.exe did not start... Trying again
```

Yet running `komorebi.exe` directly in a terminal works fine.

### Root Cause

`komorebi.json` is a **symbolic link** instead of a regular file.
`komorebic start` fails to detect the process when the config it reads is a symlink.
This is a [known komorebi issue](https://github.com/LGUG2Z/komorebi/issues/1454).

In this repo, the symlink was a leftover from an older version of `switch-komorebi.ps1`
that used `New-Item -ItemType SymbolicLink` to point `komorebi.json` at the active
profile. That was removed in commit `1ebdc71`, but any symlink already on disk was
never replaced.

### Fix

Replace the symlink with a real copy of the target profile:

```powershell
$config = "$HOME\.config\komorebi\komorebi.json"
$item = Get-Item $config
if ($item.LinkType -eq 'SymbolicLink') {
    $target = $item.Target
    Remove-Item $config -Force
    Copy-Item $target $config
}
```

Or simply run `switch-komorebi.ps1 <profile>` — the updated script now uses
`Copy-Item` instead of creating a symlink.

### Prevention

- `switch-komorebi.ps1` now copies the profile file into `komorebi.json` on every switch.
- `setup-windows.ps1` detects and replaces stale symlinks during setup.
