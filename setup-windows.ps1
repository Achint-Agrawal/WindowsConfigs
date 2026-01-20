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

# Total steps for progress display
$TotalSteps = 9

# ------------------------------------------------------------------------------
# Oh My Posh Installation
# ------------------------------------------------------------------------------
Write-Host "`n[1/$TotalSteps] Oh My Posh..." -ForegroundColor Yellow

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
Write-Host "`n[2/$TotalSteps] JetBrains Mono Nerd Font..." -ForegroundColor Yellow

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
Write-Host "`n[3/$TotalSteps] PowerShell profile..." -ForegroundColor Yellow

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
Write-Host "`n[4/$TotalSteps] Windows Terminal font..." -ForegroundColor Yellow

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
Write-Host "`n[5/$TotalSteps] VS Code settings symlink..." -ForegroundColor Yellow

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
# WezTerm Installation & Configuration
# ------------------------------------------------------------------------------
Write-Host "`n[6/$TotalSteps] WezTerm..." -ForegroundColor Yellow

$WezTermInstalled = Get-Command wezterm -ErrorAction SilentlyContinue

if ($WezTermInstalled) {
    Write-Host "WezTerm already installed. Checking for updates..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade wez.wezterm -s winget --accept-package-agreements --accept-source-agreements 2>$null
    }
} else {
    Write-Host "Installing WezTerm..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install wez.wezterm -s winget --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install wezterm
    } else {
        Write-Warning "Neither winget nor scoop found. Install WezTerm manually from https://wezfurlong.org/wezterm/"
    }
}

# WezTerm config symlink - WezTerm looks for config in ~/.config/wezterm/ or ~/.wezterm.lua
$WezTermConfigSource = "$ConfigPath\wezterm"
$WezTermConfigTarget = "$env:USERPROFILE\.wezterm.lua"

if (Test-Path $WezTermConfigSource) {
    $sourceConfigFile = "$WezTermConfigSource\wezterm.lua"
    
    if (Test-Path $sourceConfigFile) {
        $existingLink = Get-Item $WezTermConfigTarget -ErrorAction SilentlyContinue
        
        if ($existingLink -and ($existingLink.LinkType -eq "SymbolicLink" -or $existingLink.LinkType -eq "HardLink")) {
            Write-Host "WezTerm config already symlinked." -ForegroundColor Green
        } elseif (Test-Path $WezTermConfigTarget) {
            # Backup existing config
            $backupFile = "$env:USERPROFILE\.wezterm.lua.backup"
            if (-not (Test-Path $backupFile)) {
                Move-Item $WezTermConfigTarget $backupFile -Force
                Write-Host "Backed up existing WezTerm config to: $backupFile" -ForegroundColor Gray
            } else {
                Remove-Item $WezTermConfigTarget -Force
            }
            New-Item -ItemType SymbolicLink -Path $WezTermConfigTarget -Target $sourceConfigFile -Force | Out-Null
            Write-Host "WezTerm config symlinked!" -ForegroundColor Green
        } else {
            New-Item -ItemType SymbolicLink -Path $WezTermConfigTarget -Target $sourceConfigFile -Force | Out-Null
            Write-Host "WezTerm config symlinked!" -ForegroundColor Green
        }
    }
} else {
    Write-Host "WezTerm config folder not found in repo. Skipping config symlink." -ForegroundColor Gray
}

if (Get-Command wezterm -ErrorAction SilentlyContinue) {
    Write-Host "WezTerm ready." -ForegroundColor Green
} else {
    Write-Warning "WezTerm may not be in PATH yet. You may need to restart your terminal."
}

# ------------------------------------------------------------------------------
# Komorebi Installation & Configuration
# ------------------------------------------------------------------------------
Write-Host "`n[7/$TotalSteps] Komorebi (tiling window manager)..." -ForegroundColor Yellow

$KomorebiInstalled = Get-Command komorebic -ErrorAction SilentlyContinue

if ($KomorebiInstalled) {
    Write-Host "Komorebi already installed. Checking for updates..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade LGUG2Z.komorebi -s winget --accept-package-agreements --accept-source-agreements 2>$null
        winget upgrade LGUG2Z.whkd -s winget --accept-package-agreements --accept-source-agreements 2>$null
    }
} else {
    Write-Host "Installing Komorebi and whkd (hotkey daemon)..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install LGUG2Z.komorebi -s winget --accept-package-agreements --accept-source-agreements
        winget install LGUG2Z.whkd -s winget --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop bucket add extras
        scoop install komorebi whkd
    } else {
        Write-Warning "Neither winget nor scoop found. Install Komorebi manually from https://github.com/LGUG2Z/komorebi"
    }
}

# Set KOMOREBI_CONFIG_HOME environment variable
$KomorebiConfigHome = "$ConfigPath\komorebi"
$CurrentKomorebiConfigHome = [System.Environment]::GetEnvironmentVariable("KOMOREBI_CONFIG_HOME", "User")

if ($CurrentKomorebiConfigHome -ne $KomorebiConfigHome) {
    [System.Environment]::SetEnvironmentVariable("KOMOREBI_CONFIG_HOME", $KomorebiConfigHome, "User")
    $env:KOMOREBI_CONFIG_HOME = $KomorebiConfigHome
    Write-Host "Set KOMOREBI_CONFIG_HOME to: $KomorebiConfigHome" -ForegroundColor Gray
} else {
    Write-Host "KOMOREBI_CONFIG_HOME already set." -ForegroundColor Gray
}

# whkdrc symlink - whkd looks for config at ~/.config/whkdrc
$WhkdrcSource = "$ConfigPath\whkdrc"
$WhkdrcTarget = "$env:USERPROFILE\.config\whkdrc"

if (Test-Path $WhkdrcSource) {
    $existingLink = Get-Item $WhkdrcTarget -ErrorAction SilentlyContinue
    
    if ($existingLink -and ($existingLink.LinkType -eq "SymbolicLink" -or $existingLink.LinkType -eq "HardLink")) {
        Write-Host "whkdrc already symlinked." -ForegroundColor Green
    } elseif (Test-Path $WhkdrcTarget) {
        Remove-Item $WhkdrcTarget -Force
        New-Item -ItemType SymbolicLink -Path $WhkdrcTarget -Target $WhkdrcSource -Force | Out-Null
        Write-Host "whkdrc symlinked!" -ForegroundColor Green
    } else {
        New-Item -ItemType SymbolicLink -Path $WhkdrcTarget -Target $WhkdrcSource -Force | Out-Null
        Write-Host "whkdrc symlinked!" -ForegroundColor Green
    }
}

# Create default komorebi.json symlink if it doesn't exist (defaults to home profile)
$KomorebiDefaultConfig = "$KomorebiConfigHome\komorebi.json"
$KomorebiHomeConfig = "$KomorebiConfigHome\komorebi.home.json"

if (-not (Test-Path $KomorebiDefaultConfig) -and (Test-Path $KomorebiHomeConfig)) {
    New-Item -ItemType SymbolicLink -Path $KomorebiDefaultConfig -Target $KomorebiHomeConfig -Force | Out-Null
    Write-Host "Created default komorebi.json symlink (pointing to home profile)." -ForegroundColor Gray
    Write-Host "Use switch-komorebi.ps1 to change profiles." -ForegroundColor Gray
}

# Register Komorebi autostart (scheduled task)
if (Get-Command komorebic -ErrorAction SilentlyContinue) {
    $taskName = 'Komorebi Autostart'
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        Write-Host "Komorebi autostart task already registered." -ForegroundColor Green
    } else {
        Write-Host "Registering Komorebi autostart task..." -ForegroundColor Gray
        try {
            # Find komorebic executable path
            $komorebicPath = (Get-Command komorebic).Source
            $action = New-ScheduledTaskAction -Execute $komorebicPath -Argument "start --whkd"
            $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Launch Komorebi tiling window manager at user logon" | Out-Null
            Write-Host "Komorebi autostart task registered!" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to register Komorebi autostart task: $_"
        }
    }
    Write-Host "Komorebi ready." -ForegroundColor Green
} else {
    Write-Warning "Komorebi may not be in PATH yet. You may need to restart your terminal."
}

# ------------------------------------------------------------------------------
# YASB (Yet Another Status Bar) Installation & Configuration
# ------------------------------------------------------------------------------
Write-Host "`n[8/$TotalSteps] YASB (status bar)..." -ForegroundColor Yellow

# Stop YASB if running (to allow config changes and updates)
$yasbProcess = Get-Process yasb -ErrorAction SilentlyContinue
if ($yasbProcess) {
    Write-Host "Stopping YASB..." -ForegroundColor Gray
    Stop-Process -Name yasb -Force
    Start-Sleep -Milliseconds 500
}

$YasbExe = "C:\Program Files\YASB\yasb.exe"
$YasbInstalled = Test-Path $YasbExe

if ($YasbInstalled) {
    Write-Host "YASB already installed." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade AmN.yasb -s winget --accept-package-agreements --accept-source-agreements 2>$null
    }
} else {
    Write-Host "Installing YASB..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install AmN.yasb -s winget --accept-package-agreements --accept-source-agreements
    } else {
        Write-Warning "winget not found. Install YASB manually from https://github.com/amnweb/yasb"
    }
}

# YASB config symlink - YASB looks for config in ~/.config/yasb/
$YasbConfigSource = "$ConfigPath\yasb"
$YasbConfigTarget = "$env:USERPROFILE\.config\yasb"

# Check if source and target are the same (repo already in correct location)
if ($YasbConfigSource -eq $YasbConfigTarget) {
    if (Test-Path $YasbConfigSource) {
        Write-Host "YASB config already in correct location." -ForegroundColor Green
    } else {
        Write-Host "YASB config folder not found. Skipping config setup." -ForegroundColor Gray
    }
} elseif (Test-Path $YasbConfigSource) {
    $existingLink = Get-Item $YasbConfigTarget -ErrorAction SilentlyContinue
    
    if ($existingLink -and ($existingLink.LinkType -eq "Junction" -or $existingLink.LinkType -eq "SymbolicLink")) {
        $target = $existingLink.Target
        if ($target -eq $YasbConfigSource) {
            Write-Host "YASB config already symlinked." -ForegroundColor Green
        } else {
            Write-Host "YASB config folder is linked to: $target" -ForegroundColor Gray
        }
    } elseif (Test-Path $YasbConfigTarget) {
        # YASB config exists but is not a symlink - backup and symlink
        $backupPath = "$env:USERPROFILE\.config\yasb.backup"
        if (-not (Test-Path $backupPath)) {
            Move-Item $YasbConfigTarget $backupPath -Force
            Write-Host "Backed up existing YASB config to: $backupPath" -ForegroundColor Gray
        } else {
            Remove-Item $YasbConfigTarget -Recurse -Force
        }
        New-Item -ItemType Junction -Path $YasbConfigTarget -Target $YasbConfigSource -Force | Out-Null
        Write-Host "YASB config symlinked!" -ForegroundColor Green
    } else {
        # Ensure parent directory exists
        $YasbConfigParent = Split-Path $YasbConfigTarget -Parent
        if (-not (Test-Path $YasbConfigParent)) {
            New-Item -ItemType Directory -Path $YasbConfigParent -Force | Out-Null
        }
        New-Item -ItemType Junction -Path $YasbConfigTarget -Target $YasbConfigSource -Force | Out-Null
        Write-Host "YASB config symlinked!" -ForegroundColor Green
    }
} else {
    Write-Host "YASB config folder not found in repo. Skipping config symlink." -ForegroundColor Gray
}

# Register YASB autostart (scheduled task)
if (Test-Path $YasbExe) {
    $taskName = 'YASB Autostart'
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if ($existingTask) {
        Write-Host "YASB autostart task already registered." -ForegroundColor Green
    } else {
        Write-Host "Registering YASB autostart task..." -ForegroundColor Gray
        try {
            $action = New-ScheduledTaskAction -Execute $YasbExe
            $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
            $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
            Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Launch YASB bar at user logon" | Out-Null
            Write-Host "YASB autostart task registered!" -ForegroundColor Green
        } catch {
            Write-Warning "Failed to register YASB autostart task: $_"
            Write-Host "You can manually run: $ConfigPath\yasb\autostart-yasb.ps1 -RegisterTask" -ForegroundColor Gray
        }
    }
    Write-Host "YASB ready." -ForegroundColor Green
} else {
    Write-Warning "YASB executable not found. It may need to be installed first."
}

# ------------------------------------------------------------------------------
# Switcheroo Installation
# ------------------------------------------------------------------------------
Write-Host "`n[9/$TotalSteps] Switcheroo (app switcher)..." -ForegroundColor Yellow

$SwitcherooInstalled = Get-Command Switcheroo -ErrorAction SilentlyContinue

if ($SwitcherooInstalled) {
    Write-Host "Switcheroo already installed. Checking for updates..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade kvakulo.Switcheroo -s winget --accept-package-agreements --accept-source-agreements 2>$null
    }
} else {
    Write-Host "Installing Switcheroo..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install kvakulo.Switcheroo -s winget --accept-package-agreements --accept-source-agreements
    } else {
        Write-Warning "winget not found. Install Switcheroo manually from https://github.com/kvakulo/Switcheroo"
    }
}

if (Get-Command Switcheroo -ErrorAction SilentlyContinue) {
    Write-Host "Switcheroo ready." -ForegroundColor Green
} else {
    Write-Warning "Switcheroo may not be in PATH yet. You may need to restart your terminal."
}

# ------------------------------------------------------------------------------
# Done
# ------------------------------------------------------------------------------
Write-Host "`n=== Setup Complete ===" -ForegroundColor Cyan
Write-Host "Restart your terminal to apply changes." -ForegroundColor Yellow

Write-Host "`nQuick Start Guide:" -ForegroundColor Cyan
Write-Host "  - Komorebi: Starts automatically at login (or run 'komorebic start --whkd')" -ForegroundColor Gray
Write-Host "  - Switch Komorebi profile via whkd shortcuts:" -ForegroundColor Gray
Write-Host "      Alt+Ctrl+H = home, Alt+Ctrl+G = ghar, Alt+Ctrl+L = laptop" -ForegroundColor Gray
Write-Host "      Alt+Ctrl+O = office.desktop, Alt+Ctrl+Shift+O = laptop.office" -ForegroundColor Gray
Write-Host "  - WezTerm: Launch from Start Menu or run 'wezterm'" -ForegroundColor Gray
Write-Host "  - YASB: Starts automatically at login, or run from Program Files" -ForegroundColor Gray
