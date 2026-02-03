# phantom-proxy Installation Script for Windows
# This script automates the installation of phantom-proxy on Windows
# Run as Administrator: .\install.ps1

#Requires -RunAsAdministrator

param(
    [string]$Version = "latest",
    [string]$InstallDir = "$env:ProgramFiles\phantom-proxy",
    [string]$ConfigDir = "$env:ProgramData\phantom-proxy"
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
        Write-Error "No releases found in the repository."
        Write-Host ""
        Write-Host "Please create a release first or specify a version:" -ForegroundColor Yellow
        Write-Host "  .\install.ps1 -Version v1.0.0" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Or install from source:" -ForegroundColor Yellow
        Write-Host "  git clone https://github.com/$GithubRepo.git" -ForegroundColor Cyan
        Write-Host "  cd phantom-proxy" -ForegroundColor Cyan
        Write-Host "  go build -o phantom-proxy.exe ./cmd" -ForegroundColor Cyan
        Write-Host "  Move-Item phantom-proxy.exe `$env:ProgramFiles\phantom-proxy\" -ForegroundColor Cyan
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
    
    Write-Warning "Npcap is not installed. Npcap is required for phantom-proxy to function."
    Write-Host ""
    
    $response = Read-Host "Do you want to download and launch the Npcap installer now? (Y/N)"
    if ($response -ne "Y" -and $response -ne "y") {
        Write-Host ""
        Write-Host "Please download and install Npcap manually from: https://npcap.com/#download" -ForegroundColor Cyan
        Write-Host "After installing Npcap, run this script again." -ForegroundColor Cyan
        exit 1
    }
    
    Write-Info "Downloading Npcap installer..."
    $npcapUrl = "https://npcap.com/dist/npcap-1.79.exe"
    $npcapInstaller = "$env:TEMP\npcap-installer.exe"
    
    try {
        Invoke-WebRequest -Uri $npcapUrl -OutFile $npcapInstaller -UseBasicParsing
        Write-Info "Launching Npcap installer..."
        Write-Host ""
        Write-Host "Please complete the Npcap installation wizard." -ForegroundColor Yellow
        Write-Host "Recommended settings:" -ForegroundColor Cyan
        Write-Host "  - Install Npcap in WinPcap API-compatible mode: YES" -ForegroundColor Cyan
        Write-Host "  - Support loopback traffic: YES" -ForegroundColor Cyan
        Write-Host ""
        
        # Launch installer and wait for it to complete
        Start-Process -FilePath $npcapInstaller -Wait
        
        Write-Host ""
        Write-Info "Npcap installer completed. Verifying installation..."
        Start-Sleep -Seconds 2
        
        # Verify installation
        if (Test-NpcapInstalled) {
            Write-Info "Npcap installed successfully"
            Remove-Item $npcapInstaller -Force -ErrorAction SilentlyContinue
        } else {
            Write-Warning "Npcap installation verification failed."
            Write-Host "If you completed the installation, you may need to restart your computer." -ForegroundColor Yellow
            Write-Host ""
            $continueResponse = Read-Host "Continue anyway? (Y/N)"
            if ($continueResponse -ne "Y" -and $continueResponse -ne "y") {
                exit 1
            }
        }
    }
    catch {
        $errMsg = $_.Exception.Message
        Write-Host 'Failed to download Npcap installer: ' -NoNewline -ForegroundColor Red
        Write-Host $errMsg -ForegroundColor Red
        Write-Host ""
        Write-Host "Please install Npcap manually from: https://npcap.com/#download" -ForegroundColor Cyan
        exit 1
    }
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
    
    $archiveName = "phantom-proxy-windows-$Arch-$Version.zip"
    $downloadUrl = "https://github.com/$GithubRepo/releases/download/$Version/$archiveName"
    
    Write-Info "Downloading phantom-proxy from $downloadUrl..."
    
    $tempZip = "$env:TEMP\phantom-proxy.zip"
    $tempExtract = "$env:TEMP\phantom-proxy-extract"
    
    try {
        Invoke-WebRequest -Uri $downloadUrl -OutFile $tempZip
    } catch {
        $errMsg = $_.Exception.Message
        Write-Host 'Failed to download binary: ' -NoNewline -ForegroundColor Red
        Write-Host $errMsg -ForegroundColor Red
        exit 1
    }
    
    Write-Info "Extracting archive..."
    
    # Extract zip file
    if (Test-Path $tempExtract) {
        Remove-Item -Path $tempExtract -Recurse -Force
    }
    Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
    
    Write-Info "Installing binary to $InstallDir\phantom-proxy.exe..."
    
    # Create installation directory
    if (-not (Test-Path $InstallDir)) {
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    }
    
    # Find and move the exe (it should be in the extracted folder)
    $exePath = Get-ChildItem -Path $tempExtract -Filter "phantom-proxy_windows_$Arch.exe" -Recurse | Select-Object -First 1
    if ($exePath) {
        Move-Item -Path $exePath.FullName -Destination "$InstallDir\phantom-proxy.exe" -Force
    } else {
        Write-Error "Could not find phantom-proxy executable in the archive"
        exit 1
    }
    
    # Cleanup
    Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $tempExtract -Recurse -Force -ErrorAction SilentlyContinue
    
    Write-Info "Binary installed successfully"
}

function Add-ToPath {
    Write-Info "Adding phantom-proxy to system PATH..."
    
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
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$GithubRepo/main/example/client.yaml.example" `
            -OutFile "$ConfigDir\client.yaml.example"
        
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/$GithubRepo/main/example/server.yaml.example" `
            -OutFile "$ConfigDir\server.yaml.example"
        
        Write-Info "Example configurations installed to $ConfigDir"
    } catch {
        $errMsg = $_.Exception.Message
        Write-Host 'Failed to download example configurations: ' -NoNewline -ForegroundColor Yellow
        Write-Host $errMsg -ForegroundColor Yellow
    }
}

function Show-PostInstallInstructions {
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Green
    Write-Info "Installation completed successfully!"
    Write-Host "=============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Option A: Use Interactive Configuration (Recommended):" -ForegroundColor Cyan
    Write-Host "   # Download and run configuration script"
    Write-Host "   Invoke-WebRequest -Uri `"https://raw.githubusercontent.com/$GithubRepo/main/configure-client.ps1`" -OutFile `"configure-client.ps1`""
    Write-Host "   .\configure-client.ps1"
    Write-Host "   # or for server:"
    Write-Host "   Invoke-WebRequest -Uri `"https://raw.githubusercontent.com/$GithubRepo/main/configure-server.ps1`" -OutFile `"configure-server.ps1`""
    Write-Host "   .\configure-server.ps1"
    Write-Host ""
    Write-Host "Option B: Manual Configuration:" -ForegroundColor Cyan
    Write-Host "   Copy-Item `"$ConfigDir\client.yaml.example`" `"$ConfigDir\config.yaml`""
    Write-Host "   # or for server:"
    Write-Host "   Copy-Item `"$ConfigDir\server.yaml.example`" `"$ConfigDir\config.yaml`""
    Write-Host ""
    Write-Host "2. Edit the configuration file (if manual):"
    Write-Host "   notepad `"$ConfigDir\config.yaml`""
    Write-Host ""
    Write-Host "3. Find your network interface GUID (if manual):"
    Write-Host "   Get-NetAdapter | Select-Object Name, InterfaceGuid"
    Write-Host "   # Use format: \\Device\\NPF_{GUID} in config"
    Write-Host ""
    Write-Host "4. Generate a secret key:"
    Write-Host "   phantom-proxy secret"
    Write-Host ""
    Write-Host "5. Run phantom-proxy (as Administrator):"
    Write-Host "   phantom-proxy run -c `"$ConfigDir\config.yaml`""
    Write-Host ""
    Write-Host "Documentation: https://github.com/$GithubRepo" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Note: Close and reopen your terminal to use 'phantom-proxy' command globally." -ForegroundColor Yellow
}

# Main installation process
function Main {
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Cyan
    Write-Host "    phantom-proxy Installation Script for Windows" -ForegroundColor Cyan
    Write-Host "=============================================================" -ForegroundColor Cyan
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
} catch {
    $errMsg = $_.Exception.Message
    Write-Host 'Installation failed: ' -NoNewline -ForegroundColor Red
    Write-Host $errMsg -ForegroundColor Red
    exit 1
}
