#!/bin/bash

# CAC Reader Setup Script for Arch and Ubuntu
# Supports: Arch Linux, Ubuntu/Debian

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Detect distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    else
        echo -e "${RED}Cannot detect distribution${NC}"
        exit 1
    fi
}

# Print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}→ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Install packages based on distro
install_packages() {
    print_info "Installing packages for $DISTRO..."
    
    case $DISTRO in
        arch|manjaro)
            sudo pacman -S --needed --noconfirm pcsclite ccid opensc pcsc-tools
            print_success "Packages installed via pacman"
            ;;
        ubuntu|debian|pop)
            sudo apt update
            sudo apt install -y pcscd libccid opensc pcsc-tools
            print_success "Packages installed via apt"
            ;;
        *)
            print_error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Configure pcscd service
configure_pcscd() {
    print_info "Configuring pcscd service..."
    
    # Stop and disable always-running service
    sudo systemctl stop pcscd.service 2>/dev/null || true
    sudo systemctl disable pcscd.service 2>/dev/null || true
    
    # Enable socket activation (on-demand)
    sudo systemctl enable pcscd.socket
    sudo systemctl start pcscd.socket
    
    print_success "pcscd configured for on-demand activation"
}

# Add user to pcscd group if needed
configure_permissions() {
    print_info "Checking permissions..."
    
    if getent group pcscd > /dev/null 2>&1; then
        if ! groups $USER | grep -q pcscd; then
            sudo usermod -aG pcscd $USER
            print_success "Added $USER to pcscd group (logout required)"
            NEED_LOGOUT=true
        else
            print_success "User already in pcscd group"
        fi
    fi
}

# Test the setup
test_setup() {
    print_info "Testing CAC reader detection..."
    
    # Wait a moment for socket activation
    sleep 1
    
    if opensc-tool --list-readers 2>/dev/null | grep -q "Reader"; then
        print_success "CAC reader detected successfully!"
        echo ""
        opensc-tool --list-readers
    else
        print_error "No reader detected. Please ensure:"
        echo "  - CAC reader is plugged in"
        echo "  - You've logged out and back in (if group was added)"
        echo "  - Run 'pcsc_scan' to diagnose"
    fi
}

# Firefox configuration instructions
firefox_instructions() {
    echo ""
    print_info "To configure Firefox:"
    echo "  1. Open Firefox and go to: about:preferences#privacy"
    echo "  2. Scroll to 'Certificates' → Click 'Security Devices'"
    echo "  3. Click 'Load' and enter:"
    echo "     Module Name: OpenSC PKCS#11"
    echo "     Module Path: /usr/lib/opensc-pkcs11.so"
    echo ""
    print_info "To configure Chrome/Chromium, run:"
    echo "  modutil -dbdir sql:\$HOME/.pki/nssdb -add \"OpenSC\" -libfile /usr/lib/opensc-pkcs11.so"
}

# Main execution
main() {
    echo "========================================="
    echo "  CAC Reader Setup Script"
    echo "========================================="
    echo ""
    
    # Check if running as root
    if [ "$EUID" -eq 0 ]; then 
        print_error "Please run as normal user (script will use sudo when needed)"
        exit 1
    fi
    
    detect_distro
    print_info "Detected distribution: $DISTRO"
    echo ""
    
    install_packages
    configure_pcscd
    configure_permissions
    test_setup
    firefox_instructions
    
    echo ""
    if [ "$NEED_LOGOUT" = true ]; then
        echo -e "${YELLOW}⚠ You must log out and back in for group changes to take effect${NC}"
    fi
    
    print_success "Setup complete!"
}

# Run main function
main
