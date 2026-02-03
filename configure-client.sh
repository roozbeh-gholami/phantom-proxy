#!/bin/bash
# phantom-proxy Client Configuration Script
# Interactive script to generate client configuration

set -e

CONFIG_FILE="${1:-config.yaml}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}▶${NC} $1"
}

# Detect network interfaces
detect_interfaces() {
    print_step "Detecting network interfaces..."
    if command -v ip &> /dev/null; then
        ip -o link show | awk -F': ' '{print $2}' | grep -v lo
    elif command -v ifconfig &> /dev/null; then
        ifconfig | grep -E '^[a-z]' | awk '{print $1}' | sed 's/://' | grep -v lo
    else
        echo "Unable to detect interfaces"
    fi
}

# Get IP address for interface
get_interface_ip() {
    local iface=$1
    if command -v ip &> /dev/null; then
        ip -4 addr show "$iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1
    elif command -v ifconfig &> /dev/null; then
        ifconfig "$iface" | grep 'inet ' | awk '{print $2}' | sed 's/addr://'
    fi
}

# Get default gateway
get_gateway() {
    if command -v ip &> /dev/null; then
        ip route | grep default | awk '{print $3}' | head -n1
    elif command -v netstat &> /dev/null; then
        netstat -rn | grep default | awk '{print $2}' | head -n1
    fi
}

# Get gateway MAC address
get_gateway_mac() {
    local gateway=$1
    if command -v arp &> /dev/null; then
        arp -n "$gateway" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -n1
    elif command -v ip &> /dev/null; then
        ip neigh show "$gateway" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -n1
    fi
}

# Generate secret key
generate_secret() {
    if command -v phantom-proxy &> /dev/null; then
        phantom-proxy secret 2>/dev/null | tail -n1
    elif command -v openssl &> /dev/null; then
        openssl rand -base64 32
    else
        echo "generated-secret-$(date +%s)"
    fi
}

print_header "phantom-proxy Client Configuration Generator"

echo ""
echo "This script will help you generate a client configuration file."
echo ""

# Step 1: Network Interface
print_step "Step 1: Network Interface"
echo "Available interfaces:"
interfaces=$(detect_interfaces)
echo "$interfaces" | nl
echo ""
read -p "Enter interface name (e.g., eth0, en0, wlan0): " INTERFACE

if [ -z "$INTERFACE" ]; then
    echo "Error: Interface name is required"
    exit 1
fi

# Step 2: Local IP Address
print_step "Step 2: Local IP Address"
detected_ip=$(get_interface_ip "$INTERFACE")
if [ -n "$detected_ip" ]; then
    print_info "Detected IP: $detected_ip"
    read -p "Use detected IP? (Y/n): " use_detected
    if [[ $use_detected =~ ^[Nn]$ ]]; then
        read -p "Enter your local IP address: " LOCAL_IP
    else
        LOCAL_IP=$detected_ip
    fi
else
    read -p "Enter your local IP address: " LOCAL_IP
fi

# Step 3: Gateway MAC Address
print_step "Step 3: Gateway/Router MAC Address"
gateway=$(get_gateway)
if [ -n "$gateway" ]; then
    print_info "Detected gateway: $gateway"
    gateway_mac=$(get_gateway_mac "$gateway")
    if [ -n "$gateway_mac" ]; then
        print_info "Detected gateway MAC: $gateway_mac"
        read -p "Use detected MAC? (Y/n): " use_detected_mac
        if [[ $use_detected_mac =~ ^[Nn]$ ]]; then
            read -p "Enter gateway MAC address (format: aa:bb:cc:dd:ee:ff): " GATEWAY_MAC
        else
            GATEWAY_MAC=$gateway_mac
        fi
    else
        echo "Run: arp -n $gateway"
        read -p "Enter gateway MAC address (format: aa:bb:cc:dd:ee:ff): " GATEWAY_MAC
    fi
else
    read -p "Enter gateway MAC address (format: aa:bb:cc:dd:ee:ff): " GATEWAY_MAC
fi

# Step 4: Server Address
print_step "Step 4: Server Configuration"
read -p "Enter phantom-proxy server address (IP:PORT, e.g., 10.0.0.100:9999): " SERVER_ADDR

# Step 5: SOCKS5 Configuration
print_step "Step 5: SOCKS5 Proxy Configuration"
read -p "SOCKS5 listen address (default: 127.0.0.1:1080): " SOCKS5_LISTEN
SOCKS5_LISTEN=${SOCKS5_LISTEN:-127.0.0.1:1080}

# Step 6: Secret Key
print_step "Step 6: Secret Key (Encryption)"
echo "Generate a new secret key or enter existing one (must match server)"
read -p "Generate new secret key? (Y/n): " gen_secret
if [[ ! $gen_secret =~ ^[Nn]$ ]]; then
    SECRET_KEY=$(generate_secret)
    print_info "Generated secret key: $SECRET_KEY"
    echo -e "${YELLOW}⚠️  Save this key! You'll need it on the server.${NC}"
else
    read -p "Enter secret key: " SECRET_KEY
fi

# Step 7: Log Level
print_step "Step 7: Logging"
read -p "Log level (none/debug/info/warn/error/fatal) [info]: " LOG_LEVEL
LOG_LEVEL=${LOG_LEVEL:-info}

# Generate configuration file
print_step "Generating configuration file..."

cat > "$CONFIG_FILE" << EOF
# phantom-proxy Client Configuration
# Generated on $(date)
role: "client"

# Logging configuration
log:
  level: "$LOG_LEVEL"

# SOCKS5 proxy configuration
socks5:
  - listen: "$SOCKS5_LISTEN"

# Network interface settings
network:
  interface: "$INTERFACE"
  
  ipv4:
    addr: "$LOCAL_IP:0"  # Port 0 = random port
    router_mac: "$GATEWAY_MAC"
  
  tcp:
    local_flag: ["PA"]
    remote_flag: ["PA"]

# Server connection settings
server:
  addr: "$SERVER_ADDR"

# Transport protocol configuration
transport:
  protocol: "kcp"
  
  kcp:
    mode: "fast"
    block: "aes"
    key: "$SECRET_KEY"
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Client configuration completed successfully! ✓"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration saved to: $CONFIG_FILE"
echo ""
echo "Next steps:"
echo ""
echo "1. Review the configuration:"
echo "   cat $CONFIG_FILE"
echo ""
echo "2. Share this secret key with your server:"
echo -e "   ${YELLOW}$SECRET_KEY${NC}"
echo ""
echo "3. Configure the server with the SAME secret key"
echo ""
echo "4. Start the server first:"
echo "   sudo phantom-proxy run -c /etc/phantom-proxy/config.yaml"
echo ""
echo "5. Then start the client:"
echo "   sudo phantom-proxy run -c $CONFIG_FILE"
echo ""
echo "6. Test the connection:"
echo "   curl https://httpbin.org/ip --proxy socks5h://$SOCKS5_LISTEN"
echo ""
echo "Documentation: https://github.com/roozbeh-gholami/phantom-proxy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
