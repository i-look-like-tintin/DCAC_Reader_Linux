#!/bin/bash

# CAC Reader Uninstall Script for Arch and Ubuntu
# Removes all CAC reader software and configurations

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

# Confirmation prompt
confirm_uninstall() {
    echo -e "${YELLOW}This will remove:${NC}"
    echo "  - pcsclite/pcscd"
    echo "  - ccid/libccid"
    echo "  - opensc"
    echo "  - pcsc-tools"
    echo "  - pcscd service configurations"
    echo "  - User group membership (pcscd)"
    echo ""
    echo -e "${YELLOW}Browser PKCS#11 module configurations will need to be removed manually.${NC}"
    echo ""
    read -p "Continue with uninstall? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Uninstall cancelled."
        exit 0
    fi
}

# Stop and disable services
stop_services() {
    print_info "Stopping and disabling pcscd services..."
    
    sudo systemctl stop pcscd.socket 2>/dev/null || true
    sudo systemctl disable pcscd.socket 2>/dev/null || true
    sudo systemctl stop pcscd.service 2>/dev/null || true
    sudo systemctl disable pcscd.service 2>/dev/null || true
    
    print_success "Services stopped and disabled"
}

# Remove user from group
remove_user_from_group() {
    print_info "Removing user from pcscd group..."
    
    if getent group pcscd > /dev/null 2>&1; then
        if groups $USER | grep -q pcscd; then
            sudo gpasswd -d $USER pcscd
            print_success "Removed $USER from pcscd group (logout required)"
            NEED_LOGOUT=true
        else
            print_info "User not in pcscd group, skipping"
        fi
    fi
}

# Remove packages based on distro
remove_packages() {
    print_info "Removing packages for $DISTRO..."
    
    case $DISTRO in
        arch|manjaro)
            sudo pacman -Rns --noconfirm pcsclite ccid opensc pcsc-tools 2>/dev/null || true
            print_success "Packages removed via pacman"
            ;;
        ubuntu|debian|pop)
            sudo apt remove --purge -y pcscd libccid opensc pcsc-tools 2>/dev/null || true
            sudo apt autoremove -y 2>/dev/null || true
            print_success "Packages removed via apt"
            ;;
        *)
            print_error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Browser cleanup instructions
browser_cleanup_instructions() {
    echo ""
    print_info "Manual browser cleanup required:"
    echo ""
    echo -e "${YELLOW}Firefox:${NC}"
    echo "  1. Open Firefox → about:preferences#privacy"
    echo "  2. Scroll to 'Certificates' → 'Security Devices'"
    echo "  3. Select 'OpenSC PKCS#11' → Click 'Unload'"
    echo ""
    echo -e "${YELLOW}Chrome/Chromium:${NC}"
    echo "  Run: modutil -dbdir sql:\$HOME/.pki/nssdb -delete \"OpenSC\""
    echo ""
}

# Check for leftover files
check_leftovers() {
    print_info "Checking for leftover configuration files..."
    
    LEFTOVER_DIRS=(
        "/etc/reader.conf.d"
        "$HOME/.eid"
    )
    
    FOUND_LEFTOVERS=false
    for dir in "${LEFTOVER_DIRS[@]}"; do
        if [ -d "$dir" ]; then
            echo "  Found: $dir"
            FOUND_LEFTOVERS=true
        fi
    done
    
    if [ "$FOUND_LEFTOVERS" = true ]; then
        echo ""
        read -p "Remove leftover configuration directories? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for dir in "${LEFTOVER_DIRS[@]}"; do
                if [ -d "$dir" ]; then
                    sudo rm -rf "$dir"
                    print_success "Removed $dir"
                fi
            done
        fi
    else
        print_success "No leftover files found"
    fi
}

# Main execution
main() {
    echo "========================================="
    echo "  CAC Reader Uninstall Script"
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
    
    confirm_uninstall
    
    echo ""
    stop_services
    remove_user_from_group
    remove_packages
    check_leftovers
    browser_cleanup_instructions
    
    echo ""
    if [ "$NEED_LOGOUT" = true ]; then
        echo -e "${YELLOW}⚠ Log out and back in to complete group removal${NC}"
    fi
    
    print_success "Uninstall complete!"
    echo ""
    echo "Your CAC reader will no longer work until you run the setup script again."
}

# Run main function
main
