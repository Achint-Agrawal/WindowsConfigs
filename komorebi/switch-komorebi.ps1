param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('laptop','laptop.office','ghar','home','luxor.shorya','office.desktop','rdp.home.into.office.desktop')]
    [string]$ProfileName
)

$cfgHome = if ($Env:KOMOREBI_CONFIG_HOME) { $Env:KOMOREBI_CONFIG_HOME } else { "$HOME\.config\komorebi" }
$target = Join-Path $cfgHome "komorebi.$ProfileName.json"
$active = Join-Path $cfgHome 'komorebi.json'

if (-not (Test-Path $target)) { exit 1 }

# Restart YASB
Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
Start-Process 'C:\Program Files\YASB\yasb.exe'

# Update symlink
if (Test-Path $active) { Remove-Item $active -Force }
New-Item -ItemType SymbolicLink -Path $active -Target $target -Force | Out-Null

# Start komorebi if not running
if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) {
    komorebic start --whkd | Out-Null
    Start-Sleep -Seconds 2
    if (-not (Get-Process komorebi -ErrorAction SilentlyContinue)) { exit 1 }
}

# Hot-swap configuration
komorebic replace-configuration $target
