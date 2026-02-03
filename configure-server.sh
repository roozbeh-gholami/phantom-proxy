#!/bin/bash
# phantom-proxy Server Configuration Script
# Interactive script to generate server configuration

set -e

CONFIG_FILE="${1:-config.yaml}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "\n${BLUE}▶${NC} $1"
}

# Detect network interfaces
detect_interfaces() {
    if command -v ip &> /dev/null; then
        ip -o link show | awk -F': ' '{print $2}' | grep -v lo
    elif command -v ifconfig &> /dev/null; then
        ifconfig | grep -E '^[a-z]' | awk '{print $1}' | sed 's/://' | grep -v lo
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

# Get gateway MAC
get_gateway_mac() {
    local gateway=$1
    if command -v arp &> /dev/null; then
        arp -n "$gateway" 2>/dev/null | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -n1
    elif command -v ip &> /dev/null; then
        ip neigh show "$gateway" | grep -oE '([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}' | head -n1
    fi
}

print_header "phantom-proxy Server Configuration Generator"

echo ""
echo "This script will help you generate a server configuration file."
echo ""

# Step 1: Network Interface
print_step "Step 1: Network Interface"
echo "Available interfaces:"
interfaces=$(detect_interfaces)
echo "$interfaces" | nl
echo ""
read -p "Enter interface name (e.g., eth0, ens3): " INTERFACE

if [ -z "$INTERFACE" ]; then
    print_error "Interface name is required"
    exit 1
fi

# Step 2: Server IP Address
print_step "Step 2: Server IP Address"
detected_ip=$(get_interface_ip "$INTERFACE")
if [ -n "$detected_ip" ]; then
    print_info "Detected IP: $detected_ip"
    read -p "Use detected IP? (Y/n): " use_detected
    if [[ $use_detected =~ ^[Nn]$ ]]; then
        read -p "Enter server IP address: " SERVER_IP
    else
        SERVER_IP=$detected_ip
    fi
else
    read -p "Enter server IP address: " SERVER_IP
fi

# Step 3: Listen Port
print_step "Step 3: Listen Port"
read -p "Enter listen port (e.g., 9999): " LISTEN_PORT

if [ -z "$LISTEN_PORT" ]; then
    print_error "Listen port is required"
    exit 1
fi

# Step 4: Gateway MAC Address
print_step "Step 4: Gateway/Router MAC Address"
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

# Step 5: Secret Key
print_step "Step 5: Secret Key (Must match client)"
read -p "Enter secret key from client: " SECRET_KEY

if [ -z "$SECRET_KEY" ]; then
    print_error "Secret key is required"
    exit 1
fi

# Step 6: Log Level
print_step "Step 6: Logging"
read -p "Log level (none/debug/info/warn/error/fatal) [info]: " LOG_LEVEL
LOG_LEVEL=${LOG_LEVEL:-info}

# Generate configuration file
print_step "Generating configuration file..."

cat > "$CONFIG_FILE" << EOF
# phantom-proxy Server Configuration
# Generated on $(date)
role: "server"

# Logging configuration
log:
  level: "$LOG_LEVEL"

# Server listen configuration
listen:
  addr: ":$LISTEN_PORT"

# Network interface settings
network:
  interface: "$INTERFACE"
  
  ipv4:
    addr: "$SERVER_IP:$LISTEN_PORT"
    router_mac: "$GATEWAY_MAC"
  
  tcp:
    local_flag: ["PA"]

# Transport protocol configuration
transport:
  protocol: "kcp"
  conn: 1
  
  kcp:
    mode: "fast"
    block: "aes"
    key: "$SECRET_KEY"
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
print_info "Server configuration completed successfully! ✓"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Configuration saved to: $CONFIG_FILE"
echo ""
print_warn "CRITICAL: Configure iptables to prevent kernel interference!"
echo ""
echo "Run these commands on the server:"
echo ""
echo -e "${YELLOW}sudo iptables -t raw -A PREROUTING -p tcp --dport $LISTEN_PORT -j NOTRACK${NC}"
echo -e "${YELLOW}sudo iptables -t raw -A OUTPUT -p tcp --sport $LISTEN_PORT -j NOTRACK${NC}"
echo -e "${YELLOW}sudo iptables -t mangle -A OUTPUT -p tcp --sport $LISTEN_PORT --tcp-flags RST RST -j DROP${NC}"
echo ""
echo "To make iptables rules persistent:"
echo "  Debian/Ubuntu: sudo iptables-save > /etc/iptables/rules.v4"
echo "  RHEL/CentOS:   sudo service iptables save"
echo ""
echo "Next steps:"
echo ""
echo "1. Configure iptables (commands above) ⚠️"
echo ""
echo "2. Review the configuration:"
echo "   cat $CONFIG_FILE"
echo ""
echo "3. Run phantom-proxy:"
echo "   sudo phantom-proxy run -c $CONFIG_FILE"
echo ""
echo "4. Check if server is listening:"
echo "   sudo netstat -tulpn | grep $LISTEN_PORT"
echo ""
echo "Documentation: https://github.com/roozbeh-gholami/phantom-proxy"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
