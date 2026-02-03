#!/bin/bash
# phantom-proxy Installation Script for Linux/macOS
# This script automates the installation of phantom-proxy

set -e

VERSION="${PHANTOM_PROXY_VERSION:-latest}"
INSTALL_DIR="${PHANTOM_PROXY_INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${PHANTOM_PROXY_CONFIG_DIR:-/etc/phantom-proxy}"
GITHUB_REPO="roozbeh-gholami/phantom-proxy"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Print functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Detect OS and architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case "$OS" in
        linux)
            OS="linux"
            ;;
        darwin)
            OS="darwin"
            ;;
        *)
            print_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    case "$ARCH" in
        x86_64|amd64)
            ARCH="amd64"
            ;;
        aarch64|arm64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="arm"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    print_info "Detected platform: ${OS}_${ARCH}"
}

# Check and install dependencies
install_dependencies() {
    print_info "Checking dependencies..."
    
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        print_info "Installing libpcap for Debian/Ubuntu..."
        apt-get update -qq
        apt-get install -y libpcap-dev wget curl
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS/Fedora
        print_info "Installing libpcap for RHEL/CentOS/Fedora..."
        yum install -y libpcap-devel wget curl
    elif command -v dnf &> /dev/null; then
        # Fedora (newer)
        print_info "Installing libpcap for Fedora..."
        dnf install -y libpcap-devel wget curl
    elif [[ "$OS" == "darwin" ]]; then
        # macOS
        print_info "Checking for libpcap on macOS..."
        if ! command -v xcode-select &> /dev/null; then
            print_warn "Xcode Command Line Tools not found. Please install: xcode-select --install"
            exit 1
        fi
        print_info "libpcap is available via Xcode Command Line Tools"
    else
        print_warn "Could not detect package manager. Please install libpcap manually."
    fi
}

# Get latest release version
get_latest_version() {
    if [ "$VERSION" = "latest" ]; then
        print_info "Fetching latest release version..."
        VERSION=$(curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        if [ -z "$VERSION" ]; then
            print_error "No releases found in the repository."
            echo ""
            echo "Please create a release first or specify a version:"
            echo "  export PHANTOM_PROXY_VERSION=v1.0.0"
            echo "  sudo ./install.sh"
            echo ""
            echo "Or install from source:"
            echo "  git clone https://github.com/${GITHUB_REPO}.git"
            echo "  cd phantom-proxy"
            echo "  go build -o phantom-proxy ./cmd"
            echo "  sudo mv phantom-proxy /usr/local/bin/"
            exit 1
        fi
        print_info "Latest version: $VERSION"
    fi
}

# Download and install binary
install_binary() {
    ARCHIVE_NAME="phantom-proxy-${OS}-${ARCH}-${VERSION}.tar.gz"
    DOWNLOAD_URL="https://github.com/${GITHUB_REPO}/releases/download/${VERSION}/${ARCHIVE_NAME}"
    
    print_info "Downloading phantom-proxy from $DOWNLOAD_URL..."
    
    TMP_DIR="/tmp/phantom-proxy-install-$$"
    TMP_FILE="$TMP_DIR/${ARCHIVE_NAME}"
    
    mkdir -p "$TMP_DIR"
    
    if command -v curl &> /dev/null; then
        curl -L -o "$TMP_FILE" "$DOWNLOAD_URL"
    elif command -v wget &> /dev/null; then
        wget -O "$TMP_FILE" "$DOWNLOAD_URL"
    else
        print_error "Neither curl nor wget found. Please install one of them."
        exit 1
    fi
    
    if [ ! -f "$TMP_FILE" ]; then
        print_error "Failed to download binary"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    print_info "Extracting archive..."
    tar -xzf "$TMP_FILE" -C "$TMP_DIR"
    
    print_info "Installing binary to $INSTALL_DIR/phantom-proxy..."
    
    # Find the binary in extracted files
    BINARY_FILE=$(find "$TMP_DIR" -name "phantom-proxy_${OS}_${ARCH}" -type f)
    
    if [ -z "$BINARY_FILE" ]; then
        print_error "Could not find phantom-proxy binary in archive"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    chmod +x "$BINARY_FILE"
    mv "$BINARY_FILE" "$INSTALL_DIR/phantom-proxy"
    
    # Cleanup
    rm -rf "$TMP_DIR"
    
    print_info "Binary installed successfully"
}

# Create configuration directory and install example configs
install_configs() {
    print_info "Creating configuration directory at $CONFIG_DIR..."
    mkdir -p "$CONFIG_DIR"
    
    print_info "Downloading example configuration files..."
    
    # Download client example
    if command -v curl &> /dev/null; then
        curl -L -o "$CONFIG_DIR/client.yaml.example" \
            "https://raw.githubusercontent.com/${GITHUB_REPO}/main/example/client.yaml.example"
        curl -L -o "$CONFIG_DIR/server.yaml.example" \
            "https://raw.githubusercontent.com/${GITHUB_REPO}/main/example/server.yaml.example"
    elif command -v wget &> /dev/null; then
        wget -O "$CONFIG_DIR/client.yaml.example" \
            "https://raw.githubusercontent.com/${GITHUB_REPO}/main/example/client.yaml.example"
        wget -O "$CONFIG_DIR/server.yaml.example" \
            "https://raw.githubusercontent.com/${GITHUB_REPO}/main/example/server.yaml.example"
    fi
    
    print_info "Example configurations installed to $CONFIG_DIR"
}

# Print post-installation instructions
print_instructions() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    print_info "Installation completed successfully! ✓"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Next steps:"
    echo ""
    echo "Option A: Use Interactive Configuration (Recommended):"
    echo "   # Download and run configuration script"
    echo "   curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/configure-client.sh -o configure-client.sh"
    echo "   chmod +x configure-client.sh"
    echo "   sudo ./configure-client.sh"
    echo "   # or for server:"
    echo "   curl -fsSL https://raw.githubusercontent.com/${GITHUB_REPO}/main/configure-server.sh -o configure-server.sh"
    echo "   chmod +x configure-server.sh"
    echo "   sudo ./configure-server.sh"
    echo ""
    echo "Option B: Manual Configuration:"
    echo "   cp $CONFIG_DIR/client.yaml.example $CONFIG_DIR/config.yaml"
    echo "   # or for server:"
    echo "   cp $CONFIG_DIR/server.yaml.example $CONFIG_DIR/config.yaml"
    echo ""
    echo "2. Edit the configuration file (if manual):"
    echo "   nano $CONFIG_DIR/config.yaml"
    echo ""
    echo "3. Generate a secret key:"
    echo "   phantom-proxy secret"
    echo ""
    echo "4. Run phantom-proxy:"
    echo "   sudo phantom-proxy run -c $CONFIG_DIR/config.yaml"
    echo ""
    echo "For server installations, remember to configure iptables:"
    echo "   sudo iptables -t raw -A PREROUTING -p tcp --dport <PORT> -j NOTRACK"
    echo "   sudo iptables -t raw -A OUTPUT -p tcp --sport <PORT> -j NOTRACK"
    echo "   sudo iptables -t mangle -A OUTPUT -p tcp --sport <PORT> --tcp-flags RST RST -j DROP"
    echo ""
    echo "Documentation: https://github.com/${GITHUB_REPO}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Main installation process
main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         phantom-proxy Installation Script                 ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    check_root
    detect_platform
    install_dependencies
    get_latest_version
    install_binary
    install_configs
    print_instructions
}

main "$@"
