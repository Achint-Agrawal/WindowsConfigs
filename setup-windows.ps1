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

# Step counter for progress display (auto-increments — no need to renumber steps)
$script:CurrentStep = 0
$TotalSteps = 15
function Write-Step($label) {
    $script:CurrentStep++
    Write-Host "`n[$script:CurrentStep/$TotalSteps] $label" -ForegroundColor Yellow
}

# ------------------------------------------------------------------------------
# Oh My Posh Installation
# ------------------------------------------------------------------------------
Write-Step "Oh My Posh..."

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
Write-Step "JetBrains Mono Nerd Font..."

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
Write-Step "PowerShell profile..."

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
Write-Step "Windows Terminal font..."

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
# VS Code Installation
# ------------------------------------------------------------------------------
Write-Step "VS Code..."

$VSCodeInstalled = Get-Command code -ErrorAction SilentlyContinue

if ($VSCodeInstalled) {
    Write-Host "VS Code already installed. Checking for updates..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade Microsoft.VisualStudioCode -s winget --accept-package-agreements --accept-source-agreements 2>$null
    }
} else {
    Write-Host "Installing VS Code..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install Microsoft.VisualStudioCode -s winget --accept-package-agreements --accept-source-agreements
    } else {
        Write-Warning "winget not found. Install VS Code manually from https://code.visualstudio.com/"
    }
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

if (Get-Command code -ErrorAction SilentlyContinue) {
    Write-Host "VS Code ready." -ForegroundColor Green
} else {
    Write-Warning "VS Code may not be in PATH yet. You may need to restart your terminal."
}

# ------------------------------------------------------------------------------
# VS Code Settings Symlink
# ------------------------------------------------------------------------------
Write-Step "VS Code settings symlink..."

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
# PowerShell 7 Installation
# ------------------------------------------------------------------------------
Write-Step "PowerShell 7..."

$Pwsh7Installed = Get-Command pwsh -ErrorAction SilentlyContinue

if ($Pwsh7Installed) {
    $pwsh7Version = (pwsh --version) -replace 'PowerShell ', ''
    Write-Host "PowerShell 7 already installed (v$pwsh7Version). Checking for updates..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade Microsoft.PowerShell -s winget --accept-package-agreements --accept-source-agreements 2>$null
    }
} else {
    Write-Host "Installing PowerShell 7 (required by WezTerm config)..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install Microsoft.PowerShell -s winget --accept-package-agreements --accept-source-agreements
    } else {
        Write-Warning "winget not found. Install PowerShell 7 manually from https://github.com/PowerShell/PowerShell"
    }
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    Write-Host "PowerShell 7 ready." -ForegroundColor Green
} else {
    Write-Warning "PowerShell 7 may not be in PATH yet. You may need to restart your terminal."
}

# ------------------------------------------------------------------------------
# WezTerm Installation & Configuration
# ------------------------------------------------------------------------------
Write-Step "WezTerm..."

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
Write-Step "Komorebi (tiling window manager)..."

$KomorebiVersion = "0.1.38"
$KomorebiInstalled = Get-Command komorebic -ErrorAction SilentlyContinue

if ($KomorebiInstalled) {
    $currentVersion = (komorebic --version | Select-String -Pattern "komorebic (\d+\.\d+\.\d+)").Matches.Groups[1].Value
    if ($currentVersion -eq $KomorebiVersion) {
        Write-Host "Komorebi v$KomorebiVersion already installed." -ForegroundColor Green
    } else {
        Write-Host "Komorebi v$currentVersion installed, but v$KomorebiVersion required. Reinstalling..." -ForegroundColor Gray
        # Stop komorebi if running
        Get-Process komorebi, whkd -ErrorAction SilentlyContinue | Stop-Process -Force
        Start-Sleep -Seconds 1
        winget uninstall LGUG2Z.komorebi --accept-source-agreements 2>$null
        winget install LGUG2Z.komorebi -s winget --version $KomorebiVersion --accept-package-agreements --accept-source-agreements
    }
} else {
    Write-Host "Installing Komorebi v$KomorebiVersion and whkd..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install LGUG2Z.komorebi -s winget --version $KomorebiVersion --accept-package-agreements --accept-source-agreements
        winget install LGUG2Z.whkd -s winget --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop bucket add extras
        scoop install komorebi@$KomorebiVersion whkd
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

# Check if source and target are the same (repo already in correct location)
if ($WhkdrcSource -eq $WhkdrcTarget) {
    if (Test-Path $WhkdrcSource) {
        Write-Host "whkdrc already in correct location." -ForegroundColor Green
    } else {
        Write-Host "whkdrc not found. Skipping." -ForegroundColor Gray
    }
} elseif (Test-Path $WhkdrcSource) {
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
} else {
    Write-Host "whkdrc not found in repo. Skipping." -ForegroundColor Gray
}

# Create default komorebi.json if it doesn't exist (copy from laptop profile as base)
$KomorebiDefaultConfig = "$KomorebiConfigHome\komorebi.json"
$KomorebiLaptopConfig = "$KomorebiConfigHome\komorebi.laptop.json"

if (-not (Test-Path $KomorebiDefaultConfig) -and (Test-Path $KomorebiLaptopConfig)) {
    Copy-Item -Path $KomorebiLaptopConfig -Destination $KomorebiDefaultConfig
    Write-Host "Created komorebi.json from laptop profile. Edit it for this machine or use switch-komorebi.ps1 to switch profiles." -ForegroundColor Gray
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
Write-Step "YASB (status bar)..."

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
# VM Monitor Detection (komorebi.json + YASB screen)
# ------------------------------------------------------------------------------
Write-Step "VM monitor detection..."

$SetupVmScript = "$ConfigPath\komorebi\setup-vm-monitor.ps1"
if (Test-Path $SetupVmScript) {
    Write-Host "Running setup-vm-monitor.ps1..." -ForegroundColor Gray
    & $SetupVmScript
} else {
    Write-Host "setup-vm-monitor.ps1 not found, skipping." -ForegroundColor Gray
}

# ------------------------------------------------------------------------------
# Neovim Dependencies (required for LazyVim plugins)
# ------------------------------------------------------------------------------
Write-Step "Neovim dependencies..."

# Python 3 (required for luarocks and some plugins)
$PythonInstalled = $false
try {
    $pythonVersionOutput = (python --version 2>&1) | Out-String
    if ($pythonVersionOutput -match 'Python (\d+\.\d+\.\d+)') {
        $PythonInstalled = $true
        $pythonVersion = $matches[1]
        Write-Host "Python already installed (v$pythonVersion)." -ForegroundColor Green
    }
} catch {
    # Python not available
}

if (-not $PythonInstalled) {
    Write-Host "Installing Python 3..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install Python.Python.3.12 -s winget --accept-package-agreements --accept-source-agreements
        # Refresh PATH
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } else {
        Write-Warning "winget not found. Install Python manually from https://python.org/"
    }
}

# ripgrep (required for Snacks.picker.grep and LazyVim)
$RgInstalled = Get-Command rg -ErrorAction SilentlyContinue
if ($RgInstalled) {
    Write-Host "ripgrep already installed." -ForegroundColor Green
} else {
    Write-Host "Installing ripgrep..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install BurntSushi.ripgrep.MSVC -s winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install ripgrep
    } else {
        Write-Warning "Neither winget nor scoop found. Install ripgrep manually."
    }
}

# fd (required for Snacks.picker.files and explorer)
$FdInstalled = Get-Command fd -ErrorAction SilentlyContinue
if ($FdInstalled) {
    Write-Host "fd already installed." -ForegroundColor Green
} else {
    Write-Host "Installing fd..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install sharkdp.fd -s winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install fd
    } else {
        Write-Warning "Neither winget nor scoop found. Install fd manually."
    }
}

# lazygit (required for Snacks.lazygit)
$LazygitInstalled = Get-Command lazygit -ErrorAction SilentlyContinue
if ($LazygitInstalled) {
    Write-Host "lazygit already installed." -ForegroundColor Green
} else {
    Write-Host "Installing lazygit..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install JesseDuffield.lazygit -s winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install lazygit
    } else {
        Write-Warning "Neither winget nor scoop found. Install lazygit manually."
    }
}

# fzf (fuzzy finder, required for LazyVim)
$FzfInstalled = Get-Command fzf -ErrorAction SilentlyContinue
if ($FzfInstalled) {
    Write-Host "fzf already installed." -ForegroundColor Green
} else {
    Write-Host "Installing fzf..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install junegunn.fzf -s winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install fzf
    } else {
        Write-Warning "Neither winget nor scoop found. Install fzf manually."
    }
}

# C Compiler (required for nvim-treesitter parser compilation)
$GccInstalled = Get-Command gcc -ErrorAction SilentlyContinue
if ($GccInstalled) {
    Write-Host "C compiler (gcc) already installed." -ForegroundColor Green
} else {
    Write-Host "Installing C compiler (WinLibs/MinGW)..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install BrechtSanders.WinLibs.POSIX.UCRT -s winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } else {
        Write-Warning "winget not found. Install WinLibs manually from https://winlibs.com/"
    }
}

# ImageMagick (required for Snacks.image to convert images)
$MagickInstalled = Get-Command magick -ErrorAction SilentlyContinue
if ($MagickInstalled) {
    Write-Host "ImageMagick already installed." -ForegroundColor Green
} else {
    Write-Host "Installing ImageMagick..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install ImageMagick.ImageMagick -s winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } else {
        Write-Warning "winget not found. Install ImageMagick manually."
    }
}

# Ghostscript (required for PDF rendering in Snacks.image)
$GsInstalled = Get-Command gs -ErrorAction SilentlyContinue
if (-not $GsInstalled) {
    # Also check for gswin64c which is the Windows executable name
    $GsInstalled = Get-Command gswin64c -ErrorAction SilentlyContinue
}
if ($GsInstalled) {
    Write-Host "Ghostscript already installed." -ForegroundColor Green
} else {
    Write-Host "Installing Ghostscript..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install ArtifexSoftware.GhostScript -s winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } else {
        Write-Warning "winget not found. Install Ghostscript manually."
    }
}

# neovim npm package (required for Node.js provider)
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $neovimNpmInstalled = npm list -g neovim 2>$null | Select-String "neovim"
    if ($neovimNpmInstalled) {
        Write-Host "neovim npm package already installed." -ForegroundColor Green
    } else {
        Write-Host "Installing neovim npm package..." -ForegroundColor Gray
        npm install -g neovim
        Write-Host "neovim npm package installed." -ForegroundColor Green
    }
} else {
    Write-Host "npm not found. Skipping neovim npm package." -ForegroundColor Gray
}

Write-Host "Neovim dependencies ready." -ForegroundColor Green

# ------------------------------------------------------------------------------
# Neovim / LazyVim Installation
# ------------------------------------------------------------------------------
Write-Step "Neovim / LazyVim..."

$NeovimInstalled = Get-Command nvim -ErrorAction SilentlyContinue

if ($NeovimInstalled) {
    $currentVersion = (nvim --version | Select-Object -First 1) -replace 'NVIM v', ''
    Write-Host "Neovim already installed (v$currentVersion). Checking for updates..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade Neovim.Neovim -s winget --accept-package-agreements --accept-source-agreements 2>$null
    }
} else {
    Write-Host "Installing Neovim..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install Neovim.Neovim -s winget --accept-package-agreements --accept-source-agreements
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install neovim
    } else {
        Write-Warning "Neither winget nor scoop found. Install Neovim manually from https://neovim.io/"
    }
    
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
}

# LazyVim config is already in this repo at ~/.config/nvim
# Neovim on Windows looks for config at ~/AppData/Local/nvim by default
# We need to symlink it
$NvimConfigSource = "$ConfigPath\nvim"
$NvimConfigTarget = "$env:LOCALAPPDATA\nvim"

if (Test-Path $NvimConfigSource) {
    $existingLink = Get-Item $NvimConfigTarget -ErrorAction SilentlyContinue
    
    if ($existingLink -and ($existingLink.LinkType -eq "Junction" -or $existingLink.LinkType -eq "SymbolicLink")) {
        $target = $existingLink.Target
        if ($target -eq $NvimConfigSource) {
            Write-Host "Neovim config already symlinked." -ForegroundColor Green
        } else {
            Write-Host "Neovim config folder is linked to: $target" -ForegroundColor Gray
        }
    } elseif (Test-Path $NvimConfigTarget) {
        # Nvim config exists but is not a symlink - backup and symlink
        $backupPath = "$env:LOCALAPPDATA\nvim.backup"
        if (-not (Test-Path $backupPath)) {
            Move-Item $NvimConfigTarget $backupPath -Force
            Write-Host "Backed up existing Neovim config to: $backupPath" -ForegroundColor Gray
        } else {
            Remove-Item $NvimConfigTarget -Recurse -Force
        }
        New-Item -ItemType Junction -Path $NvimConfigTarget -Target $NvimConfigSource -Force | Out-Null
        Write-Host "Neovim config symlinked (LazyVim will install on first launch)." -ForegroundColor Green
    } else {
        New-Item -ItemType Junction -Path $NvimConfigTarget -Target $NvimConfigSource -Force | Out-Null
        Write-Host "Neovim config symlinked (LazyVim will install on first launch)." -ForegroundColor Green
    }
} else {
    Write-Host "Neovim config folder not found in repo. Skipping config symlink." -ForegroundColor Gray
}

if (Get-Command nvim -ErrorAction SilentlyContinue) {
    Write-Host "Neovim ready. Run 'nvim' to launch (LazyVim plugins install automatically)." -ForegroundColor Green
} else {
    Write-Warning "Neovim may not be in PATH yet. You may need to restart your terminal."
}

# Install tree-sitter-cli (required for Neovim tree-sitter parser compilation)
if (Get-Command npm -ErrorAction SilentlyContinue) {
    $treeSitterInstalled = Get-Command tree-sitter -ErrorAction SilentlyContinue
    if (-not $treeSitterInstalled) {
        Write-Host "Installing tree-sitter-cli..." -ForegroundColor Gray
        npm install -g tree-sitter-cli
        Write-Host "tree-sitter-cli installed." -ForegroundColor Green
    } else {
        Write-Host "tree-sitter-cli already installed." -ForegroundColor Green
    }
} else {
    Write-Warning "npm not found. tree-sitter-cli requires Node.js/npm to install."
}

# ------------------------------------------------------------------------------
# Switcheroo Installation
# ------------------------------------------------------------------------------
Write-Step "Switcheroo (app switcher)..."

# Check if Switcheroo is installed (it's a GUI app, may not be in PATH)
$SwitcherooExe = "$env:LOCALAPPDATA\Switcheroo\Switcheroo.exe"
$SwitcherooInstalled = (Test-Path $SwitcherooExe) -or (Get-Command Switcheroo -ErrorAction SilentlyContinue)

if ($SwitcherooInstalled) {
    Write-Host "Switcheroo already installed. Checking for updates..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade kvakulo.Switcheroo -s winget --accept-package-agreements --accept-source-agreements --include-unknown 2>$null
    }
    Write-Host "Switcheroo ready." -ForegroundColor Green
} else {
    Write-Host "Installing Switcheroo..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install kvakulo.Switcheroo -s winget --accept-package-agreements --accept-source-agreements
        Write-Host "Switcheroo installed." -ForegroundColor Green
    } else {
        Write-Warning "winget not found. Install Switcheroo manually from https://github.com/kvakulo/Switcheroo"
    }
}

# ------------------------------------------------------------------------------
# AutoHotkey Installation & UTC.ahk Autostart
# ------------------------------------------------------------------------------
Write-Step "AutoHotkey (UTC.ahk)..."

$AhkInstalled = Get-Command autohotkey -ErrorAction SilentlyContinue

if ($AhkInstalled) {
    Write-Host "AutoHotkey already installed." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget upgrade AutoHotkey.AutoHotkey -s winget --accept-package-agreements --accept-source-agreements 2>$null
    }
} else {
    Write-Host "Installing AutoHotkey..." -ForegroundColor Gray
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        winget install AutoHotkey.AutoHotkey -s winget --accept-package-agreements --accept-source-agreements
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    } elseif (Get-Command scoop -ErrorAction SilentlyContinue) {
        scoop install autohotkey
    } else {
        Write-Warning "Neither winget nor scoop found. Install AutoHotkey manually from https://www.autohotkey.com/"
    }
}

# Register UTC.ahk autostart (scheduled task)
$AhkScript = "$ConfigPath\UTC.ahk"
if (Test-Path $AhkScript) {
    $taskName = 'UTC.ahk Autostart'
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

    if ($existingTask) {
        Write-Host "UTC.ahk autostart task already registered." -ForegroundColor Green
    } else {
        Write-Host "Registering UTC.ahk autostart task..." -ForegroundColor Gray
        try {
            # Find AutoHotkey executable
            $ahkExe = (Get-Command autohotkey -ErrorAction SilentlyContinue).Source
            if (-not $ahkExe) {
                # Common install locations
                $ahkExe = "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"
                if (-not (Test-Path $ahkExe)) {
                    $ahkExe = "C:\Program Files\AutoHotkey\AutoHotkey.exe"
                }
            }

            if ($ahkExe -and (Test-Path $ahkExe)) {
                $action = New-ScheduledTaskAction -Execute $ahkExe -Argument "`"$AhkScript`""
                $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
                $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan)
                Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Launch UTC.ahk time conversion script at user logon" | Out-Null
                Write-Host "UTC.ahk autostart task registered!" -ForegroundColor Green
            } else {
                Write-Warning "AutoHotkey executable not found. Cannot register autostart task."
            }
        } catch {
            Write-Warning "Failed to register UTC.ahk autostart task: $_"
        }
    }
    Write-Host "AutoHotkey ready." -ForegroundColor Green
} else {
    Write-Host "UTC.ahk not found at $AhkScript. Skipping autostart." -ForegroundColor Gray
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
Write-Host "  - UTC.ahk: Starts automatically at login (Alt+U=UTC, Alt+I=IST, Alt+P=PST/PDT)" -ForegroundColor Gray
