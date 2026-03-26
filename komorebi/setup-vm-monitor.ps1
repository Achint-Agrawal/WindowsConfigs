<#
.SYNOPSIS
    Creates komorebi.default.json from the laptop profile with the correct monitor ID.

.DESCRIPTION
    Idempotent — safe to run multiple times. Skips steps that are already correct.
    1. Copies komorebi.laptop.json to komorebi.default.json (gitignored, local per machine)
    2. Ensures komorebi is running (starts temporarily if needed)
    3. Detects the primary monitor device_id via komorebic state
    4. Replaces display_index_preferences in komorebi.default.json with the detected ID
    5. Detects the display name via yasbc and adds it to YASB primary-bar screens
    6. Restarts komorebi with the default profile

    Requires: komorebic, yasbc (installed by setup-windows.ps1)

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
if (-not (Test-Path $laptopConfig)) {
    Write-Warning "komorebi.laptop.json not found at $laptopConfig. Run setup-windows.ps1 first."
    return
}
if (-not (Test-Path $yasbConfig)) {
    Write-Warning "YASB config.yaml not found at $yasbConfig. Run setup-windows.ps1 first."
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

# --- 5. Add display name to YASB primary-bar screens ---
Write-Host "Detecting monitor from yasbc..." -ForegroundColor Cyan
try {
    $yasbOutput = yasbc monitor-information 2>&1
    $match = $yasbOutput | Select-String 'Name:\s*(.+)'
    if (-not $match) { throw "No monitor name found in yasbc output" }
    $yasbDisplayName = $match.Matches[0].Groups[1].Value.Trim()
    Write-Host "  yasbc display name  : $yasbDisplayName" -ForegroundColor Gray

    Write-Host "Updating YASB config.yaml..." -ForegroundColor Cyan
    $yasbContent = Get-Content $yasbConfig -Raw

    if ($yasbContent -match [regex]::Escape($yasbDisplayName)) {
        Write-Host "  YASB screens already contains '$yasbDisplayName'." -ForegroundColor Green
    } elseif ($PSCmdlet.ShouldProcess($yasbConfig, "Add '$yasbDisplayName' to primary-bar screens")) {
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
} catch {
    Write-Warning "Failed to update YASB config: $_"
    return
}

# --- 6. Restart komorebi with default profile ---
Write-Host "Restarting komorebi..." -ForegroundColor Cyan
if ($PSCmdlet.ShouldProcess("komorebi", "Restart with komorebi.default.json")) {
    komorebic stop --whkd 2>$null
    Start-Sleep -Milliseconds 500
    komorebic start --whkd --config $defaultConfig | Out-Null
}

Write-Host "VM monitor setup complete." -ForegroundColor Green
Write-Host "  Profile : komorebi.default.json (copied from laptop)" -ForegroundColor Gray
Write-Host "  Monitor : $monitorName" -ForegroundColor Gray
Write-Host "  Device  : $deviceId" -ForegroundColor Gray
