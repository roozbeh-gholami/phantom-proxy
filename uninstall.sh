#!/bin/bash
# paqet Uninstallation Script for Linux/macOS

set -e

INSTALL_DIR="${PAQET_INSTALL_DIR:-/usr/local/bin}"
CONFIG_DIR="${PAQET_CONFIG_DIR:-/etc/paqet}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

remove_binary() {
    if [ -f "$INSTALL_DIR/paqet" ]; then
        print_info "Removing binary from $INSTALL_DIR/paqet..."
        rm -f "$INSTALL_DIR/paqet"
        print_info "Binary removed"
    else
        print_warn "Binary not found at $INSTALL_DIR/paqet"
    fi
}

remove_configs() {
    if [ -d "$CONFIG_DIR" ]; then
        echo ""
        read -p "Remove configuration directory ($CONFIG_DIR)? [y/N]: " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_info "Removing configuration directory..."
            rm -rf "$CONFIG_DIR"
            print_info "Configuration directory removed"
        else
            print_info "Keeping configuration directory"
        fi
    else
        print_warn "Configuration directory not found at $CONFIG_DIR"
    fi
}

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         paqet Uninstallation Script                       ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    
    check_root
    remove_binary
    remove_configs
    
    echo ""
    print_info "Uninstallation completed"
    echo ""
}

main "$@"
