# paqet Installation Script for Windows
# This script automates the installation of paqet on Windows
# Run as Administrator: .\install.ps1

#Requires -RunAsAdministrator

param(
    [string]$Version = "latest",
    [string]$InstallDir = "$env:ProgramFiles\paqet",
    [string]$ConfigDir = "$env:ProgramData\paqet"
)

$ErrorActionPreference = "Stop"
$GithubRepo = "roozbeh-gholami/phantom-proxy"

# Helper functions
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Info {
    param([string]$Message)
    Write-ColorOutput "[INFO] $Message" "Green"
}

function Write-Warning {
    param([string]$Message)
    Write-ColorOutput "[WARN] $Message" "Yellow"
}

function Write-Error {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-LatestVersion {
    Write-Info "Fetching latest release version..."
    try {
        $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$GithubRepo/releases/latest"
        $latestVersion = $response.tag_name
        Write-Info "Latest version: $latestVersion"
        return $latestVersion
    }
    catch {
        Write-Error "Failed to fetch latest version: $_"
        exit 1
    }
}

function Test-NpcapInstalled {
    $npcapPath = "C:\Windows\System32\Npcap"
    $npcapDriverPath = "C:\Windows\System32\drivers\npcap.sys"
    
    if (Test-Path $npcapPath) {
        return $true
    }
    if (Test-Path $npcapDriverPath) {
        return $true
    }
    
    # Check registry
    $npcapKey = "HKLM:\SOFTWARE\Npcap"
    if (Test-Path $npcapKey) {
        return $true
    }
    
    return $false
}

function Install-Npcap {
    Write-Info "Checking for Npcap installation..."
    
    if (Test-NpcapInstalled) {
        Write-Info "Npcap is already installed"
        return
    }
    
    Write-Warning "Npcap is not installed. Npcap is required for paqet to function."
    Write-Host ""
    Write-Host "Please download and install Npcap from: https://npcap.com/#download" -ForegroundColor Cyan
    Write-Host "After installing Npcap, run this script again." -ForegroundColor Cyan
    Write-Host ""
    
    $response = Read-Host "Do you want to open the Npcap download page now? (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        Start-Process "https://npcap.com/#download"
    }
    
    exit 1
}

function Get-SystemArchitecture {
    $arch = [System.Environment]::GetEnvironmentVariable("PROCESSOR_ARCHITECTURE")
    
    switch ($arch) {
        "AMD64" { return "amd64" }
        "ARM64" { return "arm64" }
        "x86" { return "386" }
        default {
            Write-Error "Unsupported architecture: $arch"
            exit 1
        }
    }
}

function Install-Binary {
    param(
        [string]$Version,
        [string]$Arch
    )
    
    $binaryName = "paqet_windows_$Arch.exe"
    $downloadUrl = "https://github.com/$GithubRepo/releases/download/$Version/$binaryName"
    
    Write-Info "Downloading paqet from $downloadUrl..."
    
    $tempFile = "$env:TEMP\paqet.exe"
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempFile
    }
    catch {
        Write-Error "Failed to download binary: $_"
        exit 1
    }
    
    Write-Info "Installing binary to $InstallDir\paqet.exe..."
    
    # Create installation directory
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    
    # Move binary
    Move-Item -Path $tempFile -Destination "$InstallDir\paqet.exe" -Force
    
    Write-Info "Binary installed successfully"
}

function Add-ToPath {
    Write-Info "Adding paqet to system PATH..."
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    
    if ($currentPath -notlike "*$InstallDir*") {
        $newPath = "$currentPath;$InstallDir"
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        $env:Path = $newPath
        Write-Info "Added to PATH successfully"
    }
    else {
        Write-Info "Already in PATH"
    }
}

function Install-Configs {
    Write-Info "Creating configuration directory at $ConfigDir..."
    
    if (-not (Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    
    Write-Info "Downloading example configuration files..."
    
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$GithubRepo/master/example/client.yaml.example" `
            -OutFile "$ConfigDir\client.yaml.example"
        
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$GithubRepo/master/example/server.yaml.example" `
            -OutFile "$ConfigDir\server.yaml.example"
        
        Write-Info "Example configurations installed to $ConfigDir"
    }
    catch {
        Write-Warning "Failed to download example configurations: $_"
    }
}

function Show-PostInstallInstructions {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Info "Installation completed successfully! ✓"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "1. Copy and modify the example configuration:"
    Write-Host "   Copy-Item `"$ConfigDir\client.yaml.example`" `"$ConfigDir\config.yaml`""
    Write-Host "   # or for server:"
    Write-Host "   Copy-Item `"$ConfigDir\server.yaml.example`" `"$ConfigDir\config.yaml`""
    Write-Host ""
    Write-Host "2. Edit the configuration file:"
    Write-Host "   notepad `"$ConfigDir\config.yaml`""
    Write-Host ""
    Write-Host "3. Find your network interface GUID:"
    Write-Host "   Get-NetAdapter | Select-Object Name, InterfaceGuid"
    Write-Host "   # Use format: \Device\NPF_{GUID} in config"
    Write-Host ""
    Write-Host "4. Generate a secret key:"
    Write-Host "   paqet secret"
    Write-Host ""
    Write-Host "5. Run paqet (as Administrator):"
    Write-Host "   paqet run -c `"$ConfigDir\config.yaml`""
    Write-Host ""
    Write-Host "Documentation: https://github.com/$GithubRepo" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Close and reopen your terminal to use 'paqet' command globally." -ForegroundColor Yellow
}

# Main installation process
function Main {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         paqet Installation Script for Windows             ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Administrator)) {
        Write-Error "This script must be run as Administrator"
        Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
        exit 1
    }
    
    Install-Npcap
    
    $arch = Get-SystemArchitecture
    Write-Info "Detected architecture: $arch"
    
    if ($Version -eq "latest") {
        $Version = Get-LatestVersion
    }
    
    Install-Binary -Version $Version -Arch $arch
    Add-ToPath
    Install-Configs
    Show-PostInstallInstructions
}

# Run main function
try {
    Main
}
catch {
    Write-Error "Installation failed: $_"
    exit 1
}
