# phantom-proxy Server Configuration Script for Windows
# Interactive script to generate server configuration

param(
    [string]$ConfigFile = "config.yaml"
)

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Blue
    Write-Host $Message -ForegroundColor Green
    Write-Host "=============================================================" -ForegroundColor Blue
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "► $Message" -ForegroundColor Blue
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning2 {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Get-NetworkAdapters {
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object Name, InterfaceDescription, InterfaceGuid, MacAddress
}

function Get-DefaultGateway {
    param([string]$InterfaceIndex)
    $route = Get-NetRoute -InterfaceIndex $InterfaceIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
    return $route.NextHop
}

function Get-GatewayMac {
    param([string]$GatewayIP)
    $arp = arp -a $GatewayIP 2>$null | Select-String -Pattern "([0-9a-f]{2}-){5}[0-9a-f]{2}"
    if ($arp) {
        $mac = $arp.Matches.Value -replace "-", ":"
        return $mac
    }
    return $null
}

function Get-LocalIPAddress {
    param([string]$InterfaceIndex)
    $ip = Get-NetIPAddress -InterfaceIndex $InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    return $ip.IPAddress
}

Write-Header "phantom-proxy Server Configuration Generator"

Write-Host ""
Write-Host "This script will help you generate a server configuration file."
Write-Host ""

# Step 1: Network Interface
Write-Step "Step 1: Network Interface"
$adapters = Get-NetworkAdapters
$adapters | Format-Table -AutoSize Name, InterfaceDescription, MacAddress

$adapterName = Read-Host "Enter adapter name (e.g., Ethernet)"
$selectedAdapter = $adapters | Where-Object { $_.Name -eq $adapterName }

if (-not $selectedAdapter) {
    Write-Host "Error: Adapter not found" -ForegroundColor Red
    exit 1
}

$interfaceGuid = "\Device\NPF_{$($selectedAdapter.InterfaceGuid)}"

# Step 2: Server IP Address
Write-Step "Step 2: Server IP Address"
$detectedIP = Get-LocalIPAddress -InterfaceIndex $selectedAdapter.ifIndex
if ($detectedIP) {
    Write-Info "Detected IP: $detectedIP"
    $useDetected = Read-Host "Use detected IP? (Y/n)"
    if ($useDetected -eq "n" -or $useDetected -eq "N") {
        $serverIP = Read-Host "Enter server IP address"
    }
    else {
        $serverIP = $detectedIP
    }
}
else {
    $serverIP = Read-Host "Enter server IP address"
}

# Step 3: Listen Port
Write-Step "Step 3: Listen Port"
$listenPort = Read-Host "Enter listen port (e.g., 9999)"

if ([string]::IsNullOrWhiteSpace($listenPort)) {
    Write-Host "Error: Listen port is required" -ForegroundColor Red
    exit 1
}

# Step 4: Gateway MAC Address
Write-Step "Step 4: Gateway/Router MAC Address"
$gateway = Get-DefaultGateway -InterfaceIndex $selectedAdapter.ifIndex
if ($gateway) {
    Write-Info "Detected gateway: $gateway"
    $gatewayMac = Get-GatewayMac -GatewayIP $gateway
    if ($gatewayMac) {
        Write-Info "Detected gateway MAC: $gatewayMac"
        $useDetectedMac = Read-Host "Use detected MAC? (Y/n)"
        if ($useDetectedMac -eq "n" -or $useDetectedMac -eq "N") {
            $gatewayMacAddr = Read-Host "Enter gateway MAC address (format: aa:bb:cc:dd:ee:ff)"
        }
        else {
            $gatewayMacAddr = $gatewayMac
        }
    }
    else {
        Write-Host "Run: arp -a $gateway" -ForegroundColor Yellow
        $gatewayMacAddr = Read-Host "Enter gateway MAC address (format: aa:bb:cc:dd:ee:ff)"
    }
}
else {
    $gatewayMacAddr = Read-Host "Enter gateway MAC address (format: aa:bb:cc:dd:ee:ff)"
}

# Step 5: Secret Key
Write-Step "Step 5: Secret Key (Must match client)"
$secretKey = Read-Host "Enter secret key from client"

if ([string]::IsNullOrWhiteSpace($secretKey)) {
    Write-Host "Error: Secret key is required" -ForegroundColor Red
    exit 1
}

# Step 6: Log Level
Write-Step "Step 6: Logging"
$logLevel = Read-Host "Log level (none/debug/info/warn/error/fatal) [info]"
if ([string]::IsNullOrWhiteSpace($logLevel)) {
    $logLevel = "info"
}

# Generate configuration file
Write-Step "Generating configuration file..."

$configContent = @"
# phantom-proxy Server Configuration
# Generated on $(Get-Date)
role: "server"

# Logging configuration
log:
  level: "$logLevel"

# Server listen configuration
listen:
  addr: ":$listenPort"

# Network interface settings
network:
  guid: "$interfaceGuid"
  
  ipv4:
    addr: "$($serverIP):$listenPort"
    router_mac: "$gatewayMacAddr"
  
  tcp:
    local_flag: ["PA"]

# Transport protocol configuration
transport:
  protocol: "kcp"
  conn: 1
  
  kcp:
    mode: "fast"
    block: "aes"
    key: "$secretKey"
"@

$configContent | Out-File -FilePath $ConfigFile -Encoding UTF8

Write-Host ""
Write-Host "=============================================================" -ForegroundColor Green
Write-Host "Server configuration completed successfully! ✓" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration saved to: $ConfigFile"
Write-Host ""
Write-Host "CRITICAL: Configure Windows Firewall!" -ForegroundColor Yellow
Write-Host ""
Write-Host "Run this command as Administrator:" -ForegroundColor White
Write-Host ""
Write-Host "netsh advfirewall firewall add rule name=`"phantom-proxy`" dir=in action=allow protocol=TCP localport=$listenPort" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next steps:"
Write-Host ""
Write-Host "1. Configure Windows Firewall (command above) ⚠️" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Review the configuration:"
Write-Host "   cat $ConfigFile"
Write-Host ""
Write-Host "3. Run phantom-proxy (as Administrator):"
Write-Host "   phantom-proxy run -c $ConfigFile"
Write-Host ""
Write-Host "4. Check if server is listening:"
Write-Host "   netstat -an | Select-String $listenPort"
Write-Host ""
Write-Host "Documentation: https://github.com/roozbeh-gholami/phantom-proxy" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Green
Write-Host ""
