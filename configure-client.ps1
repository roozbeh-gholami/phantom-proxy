# phantom-proxy Client Configuration Script for Windows
# Interactive script to generate client configuration

param(
    [string]$ConfigFile = "config.yaml"
)

$ErrorActionPreference = "Stop"

function Write-Header {
    param([string]$Message)
    Write-Host ""
    Write-Host "=============================================================" -ForegroundColor Green
    Write-Host $Message -ForegroundColor Green
    Write-Host "=============================================================" -ForegroundColor Green
}

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "► $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
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

function Generate-SecretKey {
    if (Get-Command phantom-proxy -ErrorAction SilentlyContinue) {
        $output = phantom-proxy secret 2>$null
        return ($output | Select-Object -Last 1)
    }
    else {
        # Generate random base64 string
        $bytes = New-Object byte[] 32
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
        return [Convert]::ToBase64String($bytes)
    }
}

Write-Header "phantom-proxy Client Configuration Generator"

Write-Host ""
Write-Host "This script will help you generate a client configuration file."
Write-Host ""

# Step 1: Network Interface
Write-Step "Step 1: Network Interface"
$adapters = Get-NetworkAdapters
$adapters | Format-Table -AutoSize Name, InterfaceDescription, MacAddress

$defaultAdapter = $adapters | Select-Object -First 1
$adapterPrompt = "Enter adapter name [" + $defaultAdapter.Name + "]"
$adapterName = Read-Host $adapterPrompt
if ([string]::IsNullOrWhiteSpace($adapterName)) {
    $adapterName = $defaultAdapter.Name
}

$selectedAdapter = $adapters | Where-Object { $_.Name -eq $adapterName }

if (-not $selectedAdapter) {
    Write-Host "Error: Adapter not found" -ForegroundColor Red
    exit 1
}

$interfaceGuid = "\Device\NPF_{$($selectedAdapter.InterfaceGuid)}"

# Step 2: Local IP Address
Write-Step "Step 2: Local IP Address"
$detectedIP = Get-LocalIPAddress -InterfaceIndex $selectedAdapter.ifIndex
if ($detectedIP) {
    Write-Info "Detected IP: $detectedIP"
    $useDetected = Read-Host "Use detected IP? (Y/n)"
    if ($useDetected -eq "n" -or $useDetected -eq "N") {
        $localIP = Read-Host "Enter your local IP address"
    }
    else {
        $localIP = $detectedIP
    }
}
else {
    $localIP = Read-Host "Enter your local IP address"
}

# Step 3: Gateway MAC Address
Write-Step "Step 3: Gateway/Router MAC Address"
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

# Step 4: Server Address
Write-Step "Step 4: Server Configuration"
$serverAddr = Read-Host "Enter phantom-proxy server address (IP:PORT) [10.0.0.100:9999]"
if ([string]::IsNullOrWhiteSpace($serverAddr)) {
    $serverAddr = "10.0.0.100:9999"
}

# Step 5: SOCKS5 Configuration
Write-Step "Step 5: SOCKS5 Proxy Configuration"
$socks5Listen = Read-Host "SOCKS5 listen address [127.0.0.1:1080]"
if ([string]::IsNullOrWhiteSpace($socks5Listen)) {
    $socks5Listen = "127.0.0.1:1080"
}

# Step 6: Secret Key
Write-Step "Step 6: Secret Key (Encryption)"
Write-Host "Generate a new secret key or enter existing one (must match server)"
$genSecret = Read-Host "Generate new secret key? (Y/n)"
if ($genSecret -ne "n" -and $genSecret -ne "N") {
    $secretKey = Generate-SecretKey
    Write-Info "Generated secret key: $secretKey"
    Write-Host "âš ï¸  Save this key! You'll need it on the server." -ForegroundColor Yellow
}
else {
    $secretKey = Read-Host "Enter secret key"
}

# Step 7: Log Level
Write-Step "Step 7: Logging"
$logLevel = Read-Host "Log level (none/debug/info/warn/error/fatal) [info]"
if ([string]::IsNullOrWhiteSpace($logLevel)) {
    $logLevel = "info"
}

# Generate configuration file
Write-Step "Generating configuration file..."

$configContent = @"
# phantom-proxy Client Configuration
# Generated on $(Get-Date)
role: "client"

# Logging configuration
log:
  level: "$logLevel"

# SOCKS5 proxy configuration
socks5:
  - listen: "$socks5Listen"

# Network interface settings
network:
  interface: "$($selectedAdapter.Name)"
  guid: '$interfaceGuid'
  
  ipv4:
    addr: "$($localIP):0"  # Port 0 = random port
    router_mac: "$gatewayMacAddr"
  
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

# Server connection settings
server:
  addr: "$serverAddr"

# Transport protocol configuration
transport:
  protocol: "kcp"
  
  kcp:
    mode: "fast"
    block: "aes"
    key: "$secretKey"
"@

# Save without BOM
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($ConfigFile, $configContent, $utf8NoBom)

Write-Host ""
Write-Host "=============================================================" -ForegroundColor Green
Write-Host "Client configuration completed successfully! ✓" -ForegroundColor Green
Write-Host "=============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Configuration saved to: $ConfigFile"
Write-Host ""
Write-Host "Next steps:"
Write-Host ""
Write-Host "1. Review the configuration:"
Write-Host "   cat $ConfigFile"
Write-Host ""
Write-Host "2. Share this secret key with your server:" -ForegroundColor Yellow
Write-Host "   $secretKey" -ForegroundColor Yellow
Write-Host ""
Write-Host "3. Configure the server with the SAME secret key"
Write-Host ""
Write-Host "4. Start the server first:"
Write-Host "   phantom-proxy run -c C:\ProgramData\phantom-proxy\config.yaml"
Write-Host ""
Write-Host "5. Then start the client (as Administrator):"
Write-Host "   phantom-proxy run -c $ConfigFile"
Write-Host ""
Write-Host "6. Test the connection:"
Write-Host "   curl https://httpbin.org/ip --proxy socks5h://$socks5Listen"
Write-Host ""
Write-Host "Documentation: https://github.com/roozbeh-gholami/phantom-proxy" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Green
Write-Host ""
