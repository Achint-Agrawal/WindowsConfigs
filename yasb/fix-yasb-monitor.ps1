<#
.SYNOPSIS
    Detects the current monitor via yasbc and adds it to the YASB primary-bar screens list.

.DESCRIPTION
    Idempotent — skips if the monitor is already in the list.
    After updating config.yaml, restarts YASB so the bar appears on the new display.
#>
[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$yasbConfig = "$HOME\.config\yasb\config.yaml"

# Refresh PATH from registry (whkd may have a stale PATH)
$env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")

if (-not (Get-Command yasbc -ErrorAction SilentlyContinue)) {
    Write-Warning "yasbc not found."
    return
}
if (-not (Test-Path $yasbConfig)) {
    Write-Warning "YASB config.yaml not found at $yasbConfig."
    return
}

# Detect monitor from yasbc
$yasbOutput = yasbc monitor-information 2>&1
$match = $yasbOutput | Select-String 'Name:\s*(.+)'
if (-not $match) {
    Write-Warning "No monitor name found in yasbc output."
    return
}
$displayName = $match.Matches[0].Groups[1].Value.Trim()

$yasbContent = Get-Content $yasbConfig -Raw

# Stop YASB *before* touching config.yaml. With watch_config on, editing it while
# YASB runs triggers a hot reload, and the reloaded process never receives komorebi
# pipe events again - the workspace widget freezes on whatever workspace was focused
# at reload time. Only a fresh process gets a working subscription. Same order
# switch-komorebi.ps1 uses. Restarting unconditionally also recovers from the
# reload YASB does on its own when displays are added/removed.
Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500

if ($yasbContent.Contains("'$displayName'")) {
    Write-Host "YASB primary-bar screens already contains '$displayName'." -ForegroundColor Green
} else {
    # Add to the first screens: line (primary-bar)
    $lines = $yasbContent -split "`n"
    $replaced = $false
    $newLines = foreach ($line in $lines) {
        if (-not $replaced -and $line -match "screens:\s*\[") {
            $line -replace "(screens:\s*\[)", "`$1'$displayName', "
            $replaced = $true
        } else { $line }
    }
    ($newLines -join "`n") | Set-Content $yasbConfig -NoNewline -Encoding UTF8
    Write-Host "Added '$displayName' to primary-bar screens." -ForegroundColor Yellow
}

Start-Process yasb
Write-Host "YASB restarted." -ForegroundColor Green
