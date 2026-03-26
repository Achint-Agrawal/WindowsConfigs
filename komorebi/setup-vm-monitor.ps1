<#
.SYNOPSIS
    Creates komorebi.default.json from the laptop profile with the correct monitor ID.

.DESCRIPTION
    Idempotent — safe to run multiple times. Skips steps that are already correct.
    1. Copies komorebi.laptop.json to komorebi.default.json (gitignored, local per machine)
    2. Ensures komorebi is running (starts temporarily if needed)
    3. Detects the primary monitor device_id via komorebic state
    4. Replaces display_index_preferences in komorebi.default.json with the detected ID
    5. Restarts komorebi with the default profile

    Requires: komorebic (installed by setup-windows.ps1)

.EXAMPLE
    .\setup-vm-monitor.ps1
    .\setup-vm-monitor.ps1 -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$configRoot = "$HOME\.config"
$laptopConfig = "$configRoot\komorebi\komorebi.laptop.json"
$defaultConfig = "$configRoot\komorebi\komorebi.default.json"

# --- Prerequisites ---
if (-not (Get-Command komorebic -ErrorAction SilentlyContinue)) {
    Write-Warning "komorebic not found in PATH. Skipping VM monitor setup."
    return
}
if (-not (Test-Path $laptopConfig)) {
    Write-Warning "komorebi.laptop.json not found at $laptopConfig. Run setup-windows.ps1 first."
    return
}

# --- 1. Copy laptop profile to default ---
Write-Host "Copying laptop profile to komorebi.default.json..." -ForegroundColor Cyan
if ($PSCmdlet.ShouldProcess($defaultConfig, "Copy from $laptopConfig")) {
    Copy-Item $laptopConfig $defaultConfig -Force
    Write-Host "  Copied komorebi.laptop.json -> komorebi.default.json" -ForegroundColor Yellow
}

# --- 2. Ensure komorebi is running so we can query state ---
$startedKomorebi = $false
if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) {
    Write-Host "Starting komorebi temporarily to detect monitor..." -ForegroundColor Gray
    if ($PSCmdlet.ShouldProcess("komorebi", "Start temporarily for monitor detection")) {
        komorebic start --whkd --config $defaultConfig | Out-Null
        Start-Sleep -Seconds 2
        $startedKomorebi = $true
    }
}

# --- 3. Detect monitor from komorebic ---
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

# --- 4. Update komorebi.default.json with detected monitor ---
Write-Host "Updating komorebi.default.json..." -ForegroundColor Cyan
$komorebiJson = Get-Content $defaultConfig -Raw | ConvertFrom-Json

$oldDeviceId = $komorebiJson.display_index_preferences.'0'
if ($oldDeviceId -eq $deviceId) {
    Write-Host "  display_index_preferences already correct." -ForegroundColor Green
} elseif ($PSCmdlet.ShouldProcess($defaultConfig, "Set display_index_preferences[0] = $deviceId")) {
    $komorebiJson.display_index_preferences.'0' = $deviceId
    $komorebiJson | ConvertTo-Json -Depth 10 | Set-Content $defaultConfig -Encoding UTF8
    Write-Host "  Updated device_id: $oldDeviceId -> $deviceId" -ForegroundColor Yellow
}

# --- 5. Restart komorebi with default profile ---
Write-Host "Restarting komorebi..." -ForegroundColor Cyan
if ($PSCmdlet.ShouldProcess("komorebi", "Restart with komorebi.default.json")) {
    komorebic stop --whkd --bar 2>$null
    Start-Sleep -Milliseconds 500
    komorebic start --whkd --bar --config $defaultConfig | Out-Null
}

Write-Host "VM monitor setup complete." -ForegroundColor Green
Write-Host "  Profile : komorebi.default.json (copied from laptop)" -ForegroundColor Gray
Write-Host "  Monitor : $monitorName" -ForegroundColor Gray
Write-Host "  Device  : $deviceId" -ForegroundColor Gray
