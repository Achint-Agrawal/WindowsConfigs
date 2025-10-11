# VS Code Configuration Symlink Setup Script
# Run this script with administrator privileges when VS Code is CLOSED

$repoVSCodePath = "C:\Users\acagrawal\.config\vscode"
$vscodeUserPath = "$env:APPDATA\Code\User"
$backupPath = "$env:APPDATA\Code\User.backup"

Write-Host "VS Code Configuration Symlink Setup" -ForegroundColor Cyan
Write-Host "====================================`n" -ForegroundColor Cyan

# Check if VS Code is running
$vscodeProcesses = Get-Process -Name "Code" -ErrorAction SilentlyContinue
if ($vscodeProcesses) {
    Write-Host "❌ ERROR: VS Code is currently running!" -ForegroundColor Red
    Write-Host "Please close all VS Code windows and run this script again." -ForegroundColor Yellow
    exit 1
}

# Step 1: Backup original User folder if not already backed up
if (!(Test-Path $backupPath)) {
    Write-Host "📦 Backing up original VS Code User folder..." -ForegroundColor Yellow
    Move-Item $vscodeUserPath $backupPath -Force
    Write-Host "✓ Backup created at: $backupPath" -ForegroundColor Green
} else {
    Write-Host "✓ Backup already exists" -ForegroundColor Green
    if (Test-Path $vscodeUserPath) {
        Remove-Item $vscodeUserPath -Recurse -Force
        Write-Host "✓ Removed existing User folder" -ForegroundColor Green
    }
}

# Step 2: Create symbolic links
Write-Host "`n🔗 Creating symbolic links..." -ForegroundColor Yellow

# Create User directory as symlink to repo
New-Item -ItemType Directory -Path "$env:APPDATA\Code" -Force | Out-Null
New-Item -ItemType Junction -Path $vscodeUserPath -Target $repoVSCodePath -Force | Out-Null
Write-Host "✓ Created junction: $vscodeUserPath -> $repoVSCodePath" -ForegroundColor Green

Write-Host "`n✅ Setup complete!" -ForegroundColor Green
Write-Host "`nYour VS Code settings are now version controlled!" -ForegroundColor Cyan
Write-Host "Location: $repoVSCodePath" -ForegroundColor Cyan
Write-Host "`nYou can now:" -ForegroundColor Yellow
Write-Host "  - Edit settings in VS Code and they'll be reflected in your repo" -ForegroundColor White
Write-Host "  - Commit changes to git" -ForegroundColor White
Write-Host "  - Sync across machines by cloning your repo and running this script" -ForegroundColor White
