param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('default','laptop','laptop.office','ghar','home','luxor.shorya','office.desktop','rdp.home.into.office.desktop')]
    [string]$ProfileName
)

$target = "$HOME\.config\komorebi\komorebi.$ProfileName.json"

if (-not (Test-Path $target)) { exit 1 }

Get-Process yasb -ErrorAction SilentlyContinue | Stop-Process -Force

# Start or restart komorebi with the new config
if (Get-Process komorebi -ErrorAction SilentlyContinue) {
    komorebic stop --whkd --bar | Out-Null
    Start-Sleep -Milliseconds 500
}
komorebic start --whkd --config $target | Out-Null

# Wait for komorebi to initialize, then ensure workspace names are set
# This fixes a race condition where initial_workspace_rules can create workspaces before names are applied
Start-Sleep -Milliseconds 1000
$config = Get-Content $target | ConvertFrom-Json
for ($m = 0; $m -lt $config.monitors.Count; $m++) {
    for ($w = 0; $w -lt $config.monitors[$m].workspaces.Count; $w++) {
        $name = $config.monitors[$m].workspaces[$w].name
        if ($name) {
            komorebic workspace-name $m $w $name 2>$null
        }
    }
}

Start-Process 'C:\Program Files\YASB\yasb.exe'
