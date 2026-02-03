# phantom-proxy Uninstallation Script for Windows
# Run as Administrator: .\uninstall.ps1

#Requires -RunAsAdministrator

param(
    [string]$InstallDir = "$env:ProgramFiles\phantom-proxy",
    [string]$ConfigDir = "$env:ProgramData\phantom-proxy"
)

$ErrorActionPreference = "Stop"

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

function Remove-Binary {
    if (Test-Path "$InstallDir\phantom-proxy.exe") {
        Write-Info "Removing binary from $InstallDir\phantom-proxy.exe..."
        Remove-Item -Path "$InstallDir\phantom-proxy.exe" -Force
        
        # Remove directory if empty
        if ((Get-ChildItem -Path $InstallDir -Force | Measure-Object).Count -eq 0) {
            Remove-Item -Path $InstallDir -Force
        }
        
        Write-Info "Binary removed"
    }
    else {
        Write-Warning "Binary not found at $InstallDir\phantom-proxy.exe"
    }
}

function Remove-FromPath {
    Write-Info "Removing phantom-proxy from system PATH..."
    
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
    
    if ($currentPath -like "*$InstallDir*") {
        $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $InstallDir }) -join ';'
        [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
        Write-Info "Removed from PATH successfully"
    }
    else {
        Write-Info "Not found in PATH"
    }
}

function Remove-Configs {
    if (Test-Path $ConfigDir) {
        Write-Host ""
        $response = Read-Host "Remove configuration directory ($ConfigDir)? (Y/N)"
        
        if ($response -eq "Y" -or $response -eq "y") {
            Write-Info "Removing configuration directory..."
            Remove-Item -Path $ConfigDir -Recurse -Force
            Write-Info "Configuration directory removed"
        }
        else {
            Write-Info "Keeping configuration directory"
        }
    }
    else {
        Write-Warning "Configuration directory not found at $ConfigDir"
    }
}

function Main {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║         phantom-proxy Uninstallation Script for Windows   ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    if (-not (Test-Administrator)) {
        Write-Error "This script must be run as Administrator"
        exit 1
    }
    
    Remove-Binary
    Remove-FromPath
    Remove-Configs
    
    Write-Host ""
    Write-Info "Uninstallation completed"
    Write-Host ""
    Write-Host "Note: Npcap was not removed. Uninstall it manually if no longer needed." -ForegroundColor Yellow
    Write-Host ""
}

try {
    Main
}
catch {
    Write-Error "Uninstallation failed: $_"
    exit 1
}
