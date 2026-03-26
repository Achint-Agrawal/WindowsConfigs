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

if (-not (Get-Command yasbc -ErrorAction SilentlyContinue)) {
    Write-Warning "yasbc not found in PATH."
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

if ($yasbContent.Contains("'$displayName'")) {
    Write-Host "YASB primary-bar screens already contains '$displayName'." -ForegroundColor Green
    return
}

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

# Restart YASB
Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
Start-Process 'C:\Program Files\YASB\yasb.exe'
Write-Host "YASB restarted." -ForegroundColor Green
