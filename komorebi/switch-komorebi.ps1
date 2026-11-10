param(
    [Parameter(Position=0, Mandatory=$true)]
    [ValidateSet('default','laptop','laptop.office','ghar','home','luxor.shorya','office.desktop','rdp.home.into.office.desktop')]
    [string]$ProfileName
)

$ErrorActionPreference = 'Stop'
$target = "$HOME\.config\komorebi\komorebi.$ProfileName.json"

if (-not (Test-Path -LiteralPath $target)) { throw "Komorebi profile not found: $target" }
$config = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json

$yasbProc = Get-Process yasb -ErrorAction SilentlyContinue
if ($yasbProc) { Stop-Process -Id $yasbProc.Id -Force }

# Stop before replacing the active config so its file watcher cannot reload it mid-switch.
if (Get-Process komorebi -ErrorAction SilentlyContinue) {
    komorebic stop --whkd --bar | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Failed to stop Komorebi.' }
    $stopDeadline = (Get-Date).AddSeconds(10)
    while (Get-Process komorebi -ErrorAction SilentlyContinue) {
        if ((Get-Date) -ge $stopDeadline) { throw 'Komorebi did not exit within 10 seconds.' }
        Start-Sleep -Milliseconds 100
    }
}

# komorebic start requires a real file rather than a symlink.
$configFile = "$HOME\.config\komorebi\komorebi.json"
$configItem = Get-Item -LiteralPath $configFile -ErrorAction SilentlyContinue
if ($configItem -and $configItem.LinkType) { Remove-Item -LiteralPath $configFile -Force }
Copy-Item -LiteralPath $target -Destination $configFile -Force

# Restoring dumped runtime state would override the selected profile's workspace layout.
komorebic start --config $configFile --whkd --clean-state
if ($LASTEXITCODE -ne 0) { throw "Failed to start Komorebi with profile '$ProfileName'." }

# Wait for komorebi to initialize, then ensure workspace names are set
# This fixes a race condition where initial_workspace_rules can create workspaces before names are applied
Start-Sleep -Milliseconds 1000
for ($m = 0; $m -lt $config.monitors.Count; $m++) {
    for ($w = 0; $w -lt $config.monitors[$m].workspaces.Count; $w++) {
        $name = $config.monitors[$m].workspaces[$w].name
        if ($name) {
            komorebic workspace-name $m $w $name
            if ($LASTEXITCODE -ne 0) { throw "Failed to name workspace $w on monitor $m." }
        }
    }
}

# Preserve YASB customizations and ensure current displays are listed before starting YASB.
$yasbConfig = "$HOME\.config\yasb\config.yaml"

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
