# Windows Setup Script
# This script sets up a fresh Windows machine with my preferred configuration.
# Assumes this repo is cloned to $env:USERPROFILE\.config
# Idempotent - safe to run multiple times.

$ErrorActionPreference = "Stop"
$ConfigPath = "$env:USERPROFILE\.config"

Write-Host "=== Windows Setup Script ===" -ForegroundColor Cyan
Write-Host "Config path: $ConfigPath" -ForegroundColor Gray

# Check if running from correct location
if (-not (Test-Path "$ConfigPath\ohmyposh\config.json")) {
    Write-Error "This script must be run from $ConfigPath and the ohmyposh folder must exist."
    exit 1
}

# ------------------------------------------------------------------------------
# Oh My Posh Installation
# ------------------------------------------------------------------------------
Write-Host "`n[1/5] Oh My Posh..." -ForegroundColor Yellow

$OhMyPoshInstalled = Get-Command oh-my-posh -ErrorAction SilentlyContinue

if ($OhMyPoshInstalled) {
    $currentVersion = oh-my-posh --version
    Write-Host "Oh My Posh already installed (v$currentVersion). Checking for updates..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements
    }
} else {
    Write-Host "Installing Oh My Posh..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements
    } else {
        Write-Host "winget not found, installing Oh My Posh via PowerShell..." -ForegroundColor Gray
        Set-ExecutionPolicy Bypass -Scope Process -Force
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
    }
    
    # Refresh PATH to include oh-my-posh
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# Verify installation
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    Write-Host "Oh My Posh ready: v$(oh-my-posh --version)" -ForegroundColor Green
} else {
    Write-Warning "Oh My Posh may not be in PATH yet. You may need to restart your terminal."
}

# ------------------------------------------------------------------------------
# JetBrains Mono Nerd Font Installation
# ------------------------------------------------------------------------------
Write-Host "`n[2/5] JetBrains Mono Nerd Font..." -ForegroundColor Yellow

$FontsFolder = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
$SystemFontsFolder = "$env:WINDIR\Fonts"
$FontInstalled = $false

if (Test-Path $FontsFolder) {
    $FontInstalled = (Get-ChildItem -Path $FontsFolder -Filter "*JetBrainsMono*Nerd*" -ErrorAction SilentlyContinue).Count -gt 0
}

if (-not $FontInstalled -and (Test-Path $SystemFontsFolder)) {
    $FontInstalled = (Get-ChildItem -Path $SystemFontsFolder -Filter "*JetBrainsMono*Nerd*" -ErrorAction SilentlyContinue).Count -gt 0
}

if ($FontInstalled) {
    Write-Host "JetBrains Mono Nerd Font already installed." -ForegroundColor Green
} else {
    Write-Host "Installing JetBrains Mono Nerd Font..." -ForegroundColor Gray
    
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
        try {
            oh-my-posh font install JetBrainsMono
            Write-Host "JetBrains Mono Nerd Font installed successfully!" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to install font via oh-my-posh: $_"
            Write-Host "You can manually install from: https://www.nerdfonts.com/font-downloads" -ForegroundColor Gray
        }
    } else {
        Write-Warning "oh-my-posh not available to install fonts. Install manually from https://www.nerdfonts.com/"
    }
}

# ------------------------------------------------------------------------------
# PowerShell Profile Configuration
# ------------------------------------------------------------------------------
Write-Host "`n[3/5] PowerShell profile..." -ForegroundColor Yellow

$OhMyPoshConfig = "$ConfigPath\ohmyposh\config.json"
$ProfileLine = "oh-my-posh init pwsh --config `"$OhMyPoshConfig`" | Invoke-Expression"

$ProfileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $ProfileDir)) {
    New-Item -ItemType Directory -Path $ProfileDir -Force | Out-Null
    Write-Host "Created profile directory: $ProfileDir" -ForegroundColor Gray
}

if (-not (Test-Path $PROFILE)) {
    $ProfileLine | Out-File -FilePath $PROFILE -Encoding utf8
    Write-Host "Created new PowerShell profile." -ForegroundColor Green
} else {
    $ProfileContent = Get-Content $PROFILE -Raw -ErrorAction SilentlyContinue
    
    if ($ProfileContent -match [regex]::Escape($OhMyPoshConfig)) {
        Write-Host "PowerShell profile already configured with custom config." -ForegroundColor Green
    } elseif ($ProfileContent -match "oh-my-posh init") {
        Write-Host "Updating Oh My Posh configuration to use custom config..." -ForegroundColor Gray
        $UpdatedContent = $ProfileContent -replace 'oh-my-posh init pwsh.*\| Invoke-Expression', $ProfileLine
        $UpdatedContent | Out-File -FilePath $PROFILE -Encoding utf8 -NoNewline
        Write-Host "Updated PowerShell profile with custom config." -ForegroundColor Green
    } else {
        Add-Content -Path $PROFILE -Value "`n# Oh My Posh`n$ProfileLine"
        Write-Host "Added Oh My Posh configuration to profile." -ForegroundColor Green
    }
}

Write-Host "Profile: $PROFILE" -ForegroundColor Gray

# ------------------------------------------------------------------------------
# Windows Terminal Font Configuration
# ------------------------------------------------------------------------------
Write-Host "`n[4/5] Windows Terminal font..." -ForegroundColor Yellow

$WTSettingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$FontName = "JetBrainsMono Nerd Font"

# Profiles that need explicit font config (don't inherit defaults properly)
$ProfilesNeedingFont = @(
    "Visual Studio Debug Console"
)

if (Test-Path $WTSettingsPath) {
    try {
        $WTSettings = Get-Content $WTSettingsPath -Raw | ConvertFrom-Json
        $settingsChanged = $false
        
        # Configure default font
        $currentFont = $WTSettings.profiles.defaults.font.face
        if ($currentFont -ne $FontName) {
            if (-not $WTSettings.profiles.defaults) {
                $WTSettings.profiles | Add-Member -NotePropertyName "defaults" -NotePropertyValue @{} -Force
            }
            if (-not $WTSettings.profiles.defaults.font) {
                $WTSettings.profiles.defaults | Add-Member -NotePropertyName "font" -NotePropertyValue @{} -Force
            }
            $WTSettings.profiles.defaults.font | Add-Member -NotePropertyName "face" -NotePropertyValue $FontName -Force
            $settingsChanged = $true
            Write-Host "Set default font to $FontName." -ForegroundColor Gray
        }
        
        # Configure font for specific profiles that don't inherit defaults
        foreach ($profile in $WTSettings.profiles.list) {
            if ($ProfilesNeedingFont -contains $profile.name) {
                $profileFont = $profile.font.face
                if ($profileFont -ne $FontName) {
                    if (-not $profile.font) {
                        $profile | Add-Member -NotePropertyName "font" -NotePropertyValue @{} -Force
                    }
                    $profile.font | Add-Member -NotePropertyName "face" -NotePropertyValue $FontName -Force
                    $settingsChanged = $true
                    Write-Host "Set font for profile '$($profile.name)'." -ForegroundColor Gray
                }
            }
        }
        
        if ($settingsChanged) {
            $WTSettings | ConvertTo-Json -Depth 100 | Out-File -FilePath $WTSettingsPath -Encoding utf8
            Write-Host "Windows Terminal configured with $FontName." -ForegroundColor Green
        } else {
            Write-Host "Windows Terminal already configured with $FontName." -ForegroundColor Green
        }
    } catch {
        Write-Warning "Failed to update Windows Terminal settings: $_"
    }
} else {
    Write-Host "Windows Terminal settings not found. Skipping." -ForegroundColor Gray
}

# ------------------------------------------------------------------------------
# VS Code Settings Symlink
# ------------------------------------------------------------------------------
Write-Host "`n[5/5] VS Code settings symlink..." -ForegroundColor Yellow

$repoVSCodePath = "$ConfigPath\vscode"
$vscodeUserPath = "$env:APPDATA\Code\User"
$backupPath = "$env:APPDATA\Code\User.backup"

# Check if VS Code folder exists in repo
if (-not (Test-Path $repoVSCodePath)) {
    Write-Host "VS Code config folder not found in repo. Skipping." -ForegroundColor Gray
} else {
    # Check if already symlinked
    $existingLink = Get-Item $vscodeUserPath -ErrorAction SilentlyContinue
    
    if ($existingLink -and ($existingLink.LinkType -eq "Junction" -or $existingLink.LinkType -eq "SymbolicLink")) {
        $target = $existingLink.Target
        if ($target -eq $repoVSCodePath) {
            Write-Host "VS Code settings already symlinked." -ForegroundColor Green
        } else {
            Write-Host "VS Code User folder is linked to: $target" -ForegroundColor Gray
            Write-Host "Run setup-vscode-symlink.ps1 manually if you want to change it." -ForegroundColor Gray
        }
    } elseif (Test-Path $vscodeUserPath) {
        # VS Code folder exists but is not a symlink
        $vscodeProcesses = Get-Process -Name "Code" -ErrorAction SilentlyContinue
        if ($vscodeProcesses) {
            Write-Warning "VS Code is running. Close it and run setup-vscode-symlink.ps1 to symlink settings."
        } else {
            Write-Host "Creating VS Code settings symlink..." -ForegroundColor Gray
            
            # Backup existing
            if (-not (Test-Path $backupPath)) {
                Move-Item $vscodeUserPath $backupPath -Force
                Write-Host "Backed up existing settings to: $backupPath" -ForegroundColor Gray
            } else {
                Remove-Item $vscodeUserPath -Recurse -Force
            }
            
            # Create junction
            New-Item -ItemType Directory -Path "$env:APPDATA\Code" -Force -ErrorAction SilentlyContinue | Out-Null
            New-Item -ItemType Junction -Path $vscodeUserPath -Target $repoVSCodePath -Force | Out-Null
            Write-Host "VS Code settings symlinked!" -ForegroundColor Green
        }
    } else {
        # VS Code not installed yet, create the symlink preemptively
        Write-Host "Creating VS Code settings symlink..." -ForegroundColor Gray
        New-Item -ItemType Directory -Path "$env:APPDATA\Code" -Force -ErrorAction SilentlyContinue | Out-Null
        New-Item -ItemType Junction -Path $vscodeUserPath -Target $repoVSCodePath -Force | Out-Null
        Write-Host "VS Code settings symlinked!" -ForegroundColor Green
    }
}

# ------------------------------------------------------------------------------
# Done
# ------------------------------------------------------------------------------
Write-Host "`n=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "Restart your terminal to apply changes." -ForegroundColor Yellow
