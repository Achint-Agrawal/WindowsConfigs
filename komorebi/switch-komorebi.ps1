param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('laptop','ghar','home','luxor.shorya','office.desktop','rdp.home.into.office.desktop')]
    [string]$ProfileName
)

$cfgHome = if ($Env:KOMOREBI_CONFIG_HOME) { $Env:KOMOREBI_CONFIG_HOME } else { Join-Path $Env:USERPROFILE '.config\komorebi' }
$target = Join-Path $cfgHome ("komorebi.$ProfileName.json")
$active = Join-Path $cfgHome 'komorebi.json'

if (-not (Test-Path $target)) {
    Write-Error "Profile file not found: $target"
    exit 1
}

Write-Host "Switching to profile: $ProfileName" -ForegroundColor Yellow

# Update symlink for persistence (used on komorebi startup)
if (Test-Path $active) {
    Remove-Item $active -Force
}
New-Item -ItemType SymbolicLink -Path $active -Target $target -Force | Out-Null

# Check if komorebi is running, start it if not
if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) {
    Write-Host "Komorebi not running. Starting..." -ForegroundColor Yellow
    komorebic start --whkd | Out-Null
    Start-Sleep -Seconds 2
    
    if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) {
        Write-Error "Failed to start komorebi"
        exit 1
    }
}

# Use replace-configuration for hot-swap without restart
Write-Host "Loading configuration..." -ForegroundColor Cyan
komorebic replace-configuration $target

# Restart YASB to pick up new workspace layout
Write-Host "Restarting YASB..." -ForegroundColor Cyan
Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
Start-Process 'C:\Program Files\YASB\yasb.exe'

Write-Host "Profile '$ProfileName' applied successfully" -ForegroundColor Green
