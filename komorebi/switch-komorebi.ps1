param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('laptop','laptop.office','ghar','home','luxor.shorya','office.desktop','rdp.home.into.office.desktop')]
    [string]$ProfileName
)

$target = "$HOME\.config\komorebi\komorebi.$ProfileName.json"

if (-not (Test-Path $target)) { exit 1 }

# Start or restart komorebi with the new config
if (Get-Process komorebi -ErrorAction SilentlyContinue) {
    komorebic stop --whkd | Out-Null
    Start-Sleep -Milliseconds 500
}
komorebic start --whkd --config $target | Out-Null

# Restart YASB
Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 500
Start-Process 'C:\Program Files\YASB\yasb.exe'
