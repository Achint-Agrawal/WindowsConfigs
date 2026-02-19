<#
.SYNOPSIS
    Detects the current monitor and configures komorebi + YASB for a new VM/virtual desktop.

.DESCRIPTION
    Idempotent — safe to run multiple times. Skips steps that are already correct.
    1. Ensures komorebi is running (starts temporarily if needed)
    2. Reads the primary monitor device_id from komorebic state
    3. Reads the primary monitor display name from yasbc
    4. Updates komorebi.json with the detected device_id
    5. Adds the display name to YASB primary-bar screens (if not already present)
    6. Restarts komorebi with the updated config

.EXAMPLE
    .\setup-vm-monitor.ps1
    .\setup-vm-monitor.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$configRoot = "$HOME\.config"
$defaultConfig = "$configRoot\komorebi\komorebi.json"
$yasbConfig = "$configRoot\yasb\config.yaml"

# --- Prerequisites ---
if (-not (Get-Command komorebic -ErrorAction SilentlyContinue)) {
    Write-Warning "komorebic not found in PATH. Skipping VM monitor setup."
    return
}
if (-not (Get-Command yasbc -ErrorAction SilentlyContinue)) {
    Write-Warning "yasbc not found in PATH. Skipping VM monitor setup."
    return
}
if (-not (Test-Path $defaultConfig)) {
    Write-Warning "komorebi.json not found at $defaultConfig. Run setup-windows.ps1 first."
    return
}
if (-not (Test-Path $yasbConfig)) {
    Write-Warning "YASB config.yaml not found at $yasbConfig. Skipping VM monitor setup."
    return
}

# --- 1. Ensure komorebi is running so we can query state ---
$startedKomorebi = $false
if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) {
    Write-Host "Starting komorebi temporarily to detect monitor..." -ForegroundColor Gray
    if ($PSCmdlet.ShouldProcess("komorebi", "Start temporarily for monitor detection")) {
        komorebic start --whkd --config $defaultConfig | Out-Null
        Start-Sleep -Seconds 2
        $startedKomorebi = $true
    }
}

# --- 2. Detect monitor from komorebic ---
Write-Host "Detecting monitor from komorebic..." -ForegroundColor Cyan
try {
    $state = komorebic state 2>&1 | ConvertFrom-Json
    $monitor = $state.monitors.elements[0]
    $deviceId = $monitor.device_id
    $monitorName = $monitor.name
    Write-Host "  komorebic device_id : $deviceId" -ForegroundColor Gray
    Write-Host "  komorebic name      : $monitorName" -ForegroundColor Gray
} catch {
    Write-Warning "Failed to read komorebic state: $_"
    if ($startedKomorebi) { komorebic stop --whkd 2>$null }
    return
}

# --- 3. Detect monitor from yasbc ---
Write-Host "Detecting monitor from yasbc..." -ForegroundColor Cyan
try {
    $yasbOutput = yasbc monitor-information 2>&1
    $match = $yasbOutput | Select-String 'Name:\s*(.+)'
    if (-not $match) { throw "No monitor name found in yasbc output" }
    $yasbDisplayName = $match.Matches[0].Groups[1].Value.Trim()
    Write-Host "  yasbc display name  : $yasbDisplayName" -ForegroundColor Gray
} catch {
    Write-Warning "Failed to read yasbc monitor info: $_"
    if ($startedKomorebi) { komorebic stop --whkd 2>$null }
    return
}

# --- 4. Update komorebi.json ---
Write-Host "Updating komorebi.json..." -ForegroundColor Cyan
$komorebiJson = Get-Content $defaultConfig -Raw | ConvertFrom-Json

$oldDeviceId = $komorebiJson.display_index_preferences.'0'
if ($oldDeviceId -eq $deviceId) {
    Write-Host "  display_index_preferences already correct." -ForegroundColor Green
} elseif ($PSCmdlet.ShouldProcess($defaultConfig, "Set display_index_preferences[0] = $deviceId")) {
    $komorebiJson.display_index_preferences.'0' = $deviceId
    $komorebiJson | ConvertTo-Json -Depth 10 | Set-Content $defaultConfig -Encoding UTF8
    Write-Host "  Updated device_id: $oldDeviceId -> $deviceId" -ForegroundColor Yellow
}

# --- 5. Add display name to YASB primary-bar screens ---
Write-Host "Updating YASB config.yaml..." -ForegroundColor Cyan
$yasbContent = Get-Content $yasbConfig -Raw

if ($yasbContent -match [regex]::Escape($yasbDisplayName)) {
    Write-Host "  YASB screens already contains '$yasbDisplayName'." -ForegroundColor Green
} elseif ($PSCmdlet.ShouldProcess($yasbConfig, "Add '$yasbDisplayName' to primary-bar screens")) {
    # Only replace the first screens: line (primary-bar)
    $lines = $yasbContent -split "`n"
    $replaced = $false
    $newLines = foreach ($line in $lines) {
        if (-not $replaced -and $line -match "screens:\s*\[") {
            $line -replace "(screens:\s*\[)", "`$1'$yasbDisplayName', "
            $replaced = $true
        } else { $line }
    }
    ($newLines -join "`n") | Set-Content $yasbConfig -NoNewline -Encoding UTF8
    Write-Host "  Added '$yasbDisplayName' to primary-bar screens." -ForegroundColor Yellow
}

# --- 6. Restart komorebi with updated config ---
Write-Host "Restarting komorebi..." -ForegroundColor Cyan
if ($PSCmdlet.ShouldProcess("komorebi", "Restart with updated komorebi.json")) {
    komorebic stop --whkd 2>$null
    Start-Sleep -Milliseconds 500
    komorebic start --whkd --config $defaultConfig | Out-Null
}

Write-Host "VM monitor setup complete." -ForegroundColor Green
Write-Host "  Monitor : $monitorName ($yasbDisplayName)" -ForegroundColor Gray
Write-Host "  Device  : $deviceId" -ForegroundColor Gray
