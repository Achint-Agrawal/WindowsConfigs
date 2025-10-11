param(
    [Parameter(Position=0,Mandatory=$false)]
    [ValidateSet('laptop','ghar')]
    [string]$ProfileName,

    [switch]$List,
    
    [switch]$SkipReapply
)

# If no profile provided and -List not used, offer an interactive selector (simple loop; integrates with fzf if available)
if (-not $ProfileName) {
    if ($List -or $true) {
        $choices = 'laptop','ghar'
        if (Get-Command fzf -ErrorAction SilentlyContinue) {
            $sel = $choices | fzf --prompt 'komorebi profile > '
        } else {
            Write-Host 'Select komorebi profile:' -ForegroundColor Cyan
            for ($i=0; $i -lt $choices.Count; $i++) { Write-Host "[$i] $($choices[$i])" }
            $idx = Read-Host 'Enter number'
            if ($idx -match '^[0-9]+$' -and [int]$idx -ge 0 -and [int]$idx -lt $choices.Count) {
                $sel = $choices[[int]$idx]
            } else {
                Write-Error 'Invalid selection'; exit 1
            }
        }
        if (-not $sel) { Write-Error 'No selection made'; exit 1 }
        $ProfileName = $sel
    }
}

if (-not $ProfileName) { Write-Error 'No profile specified'; exit 1 }

$cfgHome = if ($Env:KOMOREBI_CONFIG_HOME) { $Env:KOMOREBI_CONFIG_HOME } else { Join-Path $Env:USERPROFILE '.config\komorebi' }
$target = Join-Path $cfgHome ("komorebi.$ProfileName.json")
$active = Join-Path $cfgHome 'komorebi.json'

if (-not (Test-Path $target)) {
    Write-Error "Profile file not found: $target"; exit 1
}

Write-Host "Switching Komorebi configuration to '$ProfileName'" -ForegroundColor Yellow

$symlinkCreated = $false

# Try to create symlink first (with -Force it will replace existing)
try {
    # Remove existing if it's a regular file (not a symlink)
    if ((Test-Path $active) -and -not (Get-Item $active).LinkType) {
        Remove-Item $active -Force
    }
    New-Item -ItemType SymbolicLink -Path $active -Target $target -Force -ErrorAction Stop | Out-Null
    $symlinkCreated = $true
} catch {
    Write-Warning "Could not create symbolic link (likely permissions). Falling back to file copy. $_"
    # Clean up any partial state
    if (Test-Path $active) {
        try { Remove-Item $active -Force } catch { }
    }
}

# Fallback to copy if symlink failed
if (-not $symlinkCreated) {
    try {
        Copy-Item $target $active -Force -ErrorAction Stop
    } catch {
        Write-Error "Failed to create configuration file: $_"
        exit 1
    }
}

# Verify the file exists before proceeding
if (-not (Test-Path $active)) {
    Write-Error "Failed to create active configuration file at: $active"
    exit 1
}

Write-Host ("Active configuration now points to: " + $(if ($symlinkCreated) { (Get-Item $active).Target } else { $target })) -ForegroundColor Cyan

# NOTE: Modified to enforce YASB-only bar usage. We intentionally do NOT use the komorebi built-in bar (--bar flag removed)
#       so that only YASB renders a bar. If any 'komorebi-bar' process is running (older session), we stop it.

# Restart and re-apply the same profile to ensure configuration is fully loaded (without komorebi bar)
if (-not $SkipReapply) {
    try {
        komorebic stop --whkd | Out-Null
        Start-Sleep -Milliseconds 500
        komorebic start --whkd | Out-Null
        Write-Host 'Komorebi restarted (no built-in bar) with whkd.' -ForegroundColor Green
    } catch {
        Write-Warning "Failed to restart komorebi automatically. You can run: komorebic stop --whkd; komorebic start --whkd"
    }

    # Kill legacy komorebi-bar process if present
    Get-Process -Name 'komorebi-bar' -ErrorAction SilentlyContinue | ForEach-Object { 
        try { $_ | Stop-Process -Force -ErrorAction Stop; Write-Host 'Stopped residual komorebi-bar process.' -ForegroundColor DarkYellow } catch {}
    }

    # (Optional) Launch YASB here if not already auto-started
    if (-not (Get-Process yasb -ErrorAction SilentlyContinue)) {
        $yasbPath = 'C:\Program Files\YASB\yasb.exe'
        if (Test-Path $yasbPath) {
            Start-Process $yasbPath
            Write-Host 'Started YASB bar.' -ForegroundColor Green
        } else {
            Write-Warning 'YASB executable not found at default path; ensure YASB is started separately.'
        }
    }

    Write-Host "Re-applying profile '$ProfileName' to ensure proper configuration load..." -ForegroundColor Yellow
    Start-Sleep -Milliseconds 1000
    & $PSCommandPath -ProfileName $ProfileName -SkipReapply
    Write-Host "Profile '$ProfileName' successfully applied and verified (YASB-only bar)." -ForegroundColor Green
}
