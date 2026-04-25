param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('default','laptop','laptop.office','ghar','home','luxor.shorya','office.desktop','rdp.home.into.office.desktop')]
    [string]$ProfileName
)

$target = "$HOME\.config\komorebi\komorebi.$ProfileName.json"

if (-not (Test-Path $target)) { exit 1 }

$yasbProc = Get-Process yasb -ErrorAction SilentlyContinue
if ($yasbProc) { Stop-Process -Id $yasbProc.Id -Force }

# Replace komorebi.json symlink with a real copy of the target profile
# (komorebic start fails to detect process when config is a symlink - known issue)
$configFile = "$HOME\.config\komorebi\komorebi.json"
Remove-Item $configFile -Force -ErrorAction SilentlyContinue
Copy-Item $target $configFile

# Start or restart komorebi with the new config
if (Get-Process komorebi -ErrorAction SilentlyContinue) {
    komorebic stop --whkd --bar | Out-Null
    Start-Sleep -Milliseconds 500
}
komorebic start --whkd

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

# Reset YASB config and ensure current displays are listed before starting YASB
$yasbConfig = "$HOME\.config\yasb\config.yaml"
git -C "$HOME\.config" checkout -- yasb/config.yaml 2>$null

# Refresh PATH from registry (whkd may have a stale PATH)
$env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")

if (Get-Command yasbc -ErrorAction SilentlyContinue) {
    $yasbOutput = yasbc monitor-information 2>&1
    $matches = $yasbOutput | Select-String 'Name:\s*(.+)'
    if ($matches) {
        $yasbContent = Get-Content $yasbConfig -Raw
        foreach ($m in $matches) {
            $displayName = $m.Matches[0].Groups[1].Value.Trim()
            if (-not $yasbContent.Contains("'$displayName'")) {
                $lines = $yasbContent -split "`n"
                $added = $false
                $newLines = foreach ($line in $lines) {
                    if (-not $added -and $line -match "screens:\s*\[") {
                        $line -replace "(screens:\s*\[)", "`$1'$displayName', "
                        $added = $true
                    } else { $line }
                }
                $yasbContent = $newLines -join "`n"
            }
        }
        $yasbContent | Set-Content $yasbConfig -NoNewline -Encoding UTF8
    }
}

Start-Process yasb
