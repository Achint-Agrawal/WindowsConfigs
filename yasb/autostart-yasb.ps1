<#
Autostart YASB script

Usage (one-time Scheduled Task registration):
  powershell -ExecutionPolicy Bypass -File "$Env:USERPROFILE\.config\yasb\autostart-yasb.ps1" -RegisterTask

Usage (create Startup shortcut):
  powershell -ExecutionPolicy Bypass -File "$Env:USERPROFILE\.config\yasb\autostart-yasb.ps1" -CreateStartupShortcut

Parameters:
  -RegisterTask            Registers a Windows Scheduled Task to launch YASB at user logon.
  -CreateStartupShortcut   Creates a .lnk in the user Startup folder instead of a task.
  -Force                   Re-register or overwrite existing artifacts.

This keeps komorebi bar disabled; YASB is the only bar.
#>
param(
  [switch]$RegisterTask,
  [switch]$CreateStartupShortcut,
  [switch]$Force
)

$yasbExe = "C:\Program Files\YASB\yasb.exe"
if (-not (Test-Path $yasbExe)) {
  Write-Error "YASB executable not found at: $yasbExe"; exit 1
}

if (-not ($RegisterTask -or $CreateStartupShortcut)) {
  Write-Host "No action specified. Use -RegisterTask or -CreateStartupShortcut." -ForegroundColor Yellow
  return
}

if ($RegisterTask) {
  $taskName = 'YASB Autostart'
  $existing = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  if ($existing -and -not $Force) {
    Write-Host "Scheduled Task already exists. Use -Force to recreate." -ForegroundColor Cyan
  } else {
    if ($existing) { Unregister-ScheduledTask -TaskName $taskName -Confirm:$false }
    $action = New-ScheduledTaskAction -Execute $yasbExe
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Launch YASB bar at user logon" | Out-Null
    Write-Host "Scheduled Task '$taskName' registered." -ForegroundColor Green
  }
}

if ($CreateStartupShortcut) {
  $startupDir = Join-Path $Env:APPDATA 'Microsoft\\Windows\\Start Menu\\Programs\\Startup'
  if (-not (Test-Path $startupDir)) { New-Item -ItemType Directory -Path $startupDir | Out-Null }
  $lnkPath = Join-Path $startupDir 'YASB.lnk'
  if ((Test-Path $lnkPath) -and -not $Force) {
    Write-Host "Startup shortcut already exists. Use -Force to overwrite." -ForegroundColor Cyan
  } else {
    $wsh = New-Object -ComObject WScript.Shell
    $sc = $wsh.CreateShortcut($lnkPath)
    $sc.TargetPath = $yasbExe
    $sc.WorkingDirectory = Split-Path $yasbExe
    $sc.WindowStyle = 7
    $sc.IconLocation = "$yasbExe,0"
    $sc.Description = 'Launch YASB bar at logon'
    $sc.Save()
    Write-Host "Startup shortcut created: $lnkPath" -ForegroundColor Green
  }
}
