#!/bin/bash

# CAC Reader and Citrix Workspace Uninstall Script for Arch and Ubuntu
# Removes all CAC reader software, Citrix, and configurations

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
    echo "  - Citrix Workspace (icaclient)"
    echo "  - pcscd service configurations"
    echo "  - User group membership (pcscd)"
    echo "  - Citrix SSL certificates"
    echo ""
    echo -e "${YELLOW}Browser PKCS#11 module and ICA file associations will need to be removed manually.${NC}"
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

# Remove Citrix Workspace
remove_citrix() {
    print_info "Removing Citrix Workspace..."
    
    case $DISTRO in
        arch|manjaro)
            if pacman -Qs icaclient > /dev/null 2>&1; then
                sudo pacman -Rns --noconfirm icaclient 2>/dev/null || true
                print_success "Citrix Workspace removed"
            else
                print_info "Citrix Workspace not installed, skipping"
            fi
            
            # Remove audio support if not needed by other apps
            read -p "Remove pulseaudio-alsa? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                sudo pacman -Rns --noconfirm pulseaudio-alsa 2>/dev/null || true
            fi
            ;;
            
        ubuntu|debian|pop)
            if dpkg -l | grep -q icaclient; then
                sudo apt remove --purge -y icaclient 2>/dev/null || true
                print_success "Citrix Workspace removed"
            else
                print_info "Citrix Workspace not installed, skipping"
            fi
            ;;
    esac
}

# Remove packages based on distro
remove_cac_packages() {
    print_info "Removing CAC reader packages for $DISTRO..."
    
    case $DISTRO in
        arch|manjaro)
            sudo pacman -Rns --noconfirm pcsclite ccid opensc pcsc-tools 2>/dev/null || true
            print_success "CAC reader packages removed via pacman"
            ;;
        ubuntu|debian|pop)
            sudo apt remove --purge -y pcscd libccid opensc pcsc-tools 2>/dev/null || true
            sudo apt autoremove -y 2>/dev/null || true
            print_success "CAC reader packages removed via apt"
            ;;
        *)
            print_error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Browser and Citrix cleanup instructions
cleanup_instructions() {
    echo ""
    echo "========================================="
    echo "  MANUAL CLEANUP REQUIRED"
    echo "========================================="
    echo ""
    
    print_info "Firefox - Remove PKCS#11 Module:"
    echo "  1. Open Firefox → about:preferences#privacy"
    echo "  2. Scroll to 'Certificates' → 'Security Devices'"
    echo "  3. Select 'OpenSC PKCS#11' → Click 'Unload'"
    echo ""
    
    print_info "Firefox - Remove ICA file association:"
    echo "  1. Settings → General → Files and Applications"
    echo "  2. Find 'ICA' → Change to 'Always ask'"
    echo ""
    
    print_info "Chrome/Chromium - Remove PKCS#11 Module:"
    echo "  Run: modutil -dbdir sql:\$HOME/.pki/nssdb -delete \"OpenSC\""
    echo ""
}

# Check for leftover files
check_leftovers() {
    print_info "Checking for leftover configuration files..."
    
    LEFTOVER_DIRS=(
        "/etc/reader.conf.d"
        "$HOME/.eid"
        "$HOME/.ICAClient"
        "/opt/Citrix"
    )
    
    FOUND_LEFTOVERS=false
    for dir in "${LEFTOVER_DIRS[@]}"; do
        if [ -d "$dir" ] || [ -f "$dir" ]; then
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
                if [ -d "$dir" ] || [ -f "$dir" ]; then
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
    echo "  CAC Reader & Citrix Uninstall Script"
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
    remove_citrix
    remove_cac_packages
    check_leftovers
    cleanup_instructions
    
    echo ""
    if [ "$NEED_LOGOUT" = true ]; then
        echo -e "${YELLOW}⚠ Log out and back in to complete group removal${NC}"
    fi
    
    print_success "Uninstall complete!"
    echo ""
    echo "Your CAC reader and Citrix will no longer work until you run the setup script again."
}

# Run main function
main
