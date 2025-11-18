#!/bin/bash

# CAC Reader and Citrix Workspace Setup Script for Arch and Ubuntu
# Supports: Arch Linux, Ubuntu/Debian

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_warning() {
    echo -e "${BLUE}⚠ $1${NC}"
}

# Install CAC reader packages based on distro
install_cac_packages() {
    print_info "Installing CAC reader packages for $DISTRO..."
    
    case $DISTRO in
        arch|manjaro)
            sudo pacman -S --needed --noconfirm pcsclite ccid opensc pcsc-tools
            print_success "CAC reader packages installed via pacman"
            ;;
        ubuntu|debian|pop)
            sudo apt update
            sudo apt install -y pcscd libccid opensc pcsc-tools
            print_success "CAC reader packages installed via apt"
            ;;
        *)
            print_error "Unsupported distribution: $DISTRO"
            exit 1
            ;;
    esac
}

# Detect AUR helper for Arch
detect_aur_helper() {
    if command -v yay &> /dev/null; then
        AUR_HELPER="yay"
        return 0
    elif command -v paru &> /dev/null; then
        AUR_HELPER="paru"
        return 0
    else
        return 1
    fi
}

# Install Citrix Workspace
install_citrix() {
    print_info "Installing Citrix Workspace..."
    
    case $DISTRO in
        arch|manjaro)
            # Install base-devel if not present
            if ! pacman -Qs base-devel > /dev/null; then
                print_info "Installing base-devel (required for AUR)..."
                sudo pacman -S --needed --noconfirm base-devel git
            fi
            
            # Check for AUR helper
            if detect_aur_helper; then
                print_info "Using $AUR_HELPER to install icaclient..."
                $AUR_HELPER -S --noconfirm icaclient
            else
                print_warning "No AUR helper found. Installing manually..."
                
                # Create temp directory
                TEMP_DIR=$(mktemp -d)
                cd "$TEMP_DIR"
                
                # Clone and build
                git clone https://aur.archlinux.org/icaclient.git
                cd icaclient
                makepkg -si --noconfirm
                
                # Cleanup
                cd ~
                rm -rf "$TEMP_DIR"
            fi
            
            # Install audio support
            print_info "Installing audio support..."
            sudo pacman -S --needed --noconfirm pulseaudio-alsa
            
            # Configure SSL certificates
            print_info "Configuring SSL certificates..."
            sudo openssl rehash /opt/Citrix/ICAClient/keystore/cacerts/
            
            print_success "Citrix Workspace installed"
            
            # Check for gdk-pixbuf2 issue
            PIXBUF_VERSION=$(pacman -Q gdk-pixbuf2 | awk '{print $2}')
            if [[ "$PIXBUF_VERSION" > "2.42.12" ]]; then
                print_warning "Detected gdk-pixbuf2 version $PIXBUF_VERSION"
                echo "  If Citrix hangs on 'Connecting...', you may need to downgrade:"
                echo "  sudo pacman -U /var/cache/pacman/pkg/gdk-pixbuf2-2.42.12-2-x86_64.pkg.tar.zst"
                echo "  Then add 'IgnorePkg = gdk-pixbuf2' to /etc/pacman.conf"
            fi
            ;;
            
        ubuntu|debian|pop)
            print_info "Downloading Citrix Workspace for Ubuntu/Debian..."
            
            # Create temp directory
            TEMP_DIR=$(mktemp -d)
            cd "$TEMP_DIR"
            
            # Detect architecture
            ARCH=$(dpkg --print-architecture)
            
            # Download latest version (update URL as needed)
            wget https://downloads.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html -O download.html
            
            print_warning "Please download Citrix Workspace manually from:"
            echo "  https://www.citrix.com/downloads/workspace-app/linux/workspace-app-for-linux-latest.html"
            echo ""
            echo "Select the Debian package for your architecture ($ARCH)"
            echo "Then install with: sudo dpkg -i icaclient_*.deb"
            echo "                   sudo apt-get install -f"
            
            # Cleanup
            cd ~
            rm -rf "$TEMP_DIR"
            
            CITRIX_MANUAL=true
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

# Browser and Citrix configuration instructions
configuration_instructions() {
    echo ""
    echo "========================================="
    echo "  BROWSER CONFIGURATION"
    echo "========================================="
    echo ""
    
    print_info "Firefox - Configure PKCS#11 Module:"
    echo "  1. Open Firefox → about:preferences#privacy"
    echo "  2. Scroll to 'Certificates' → Click 'Security Devices'"
    echo "  3. Click 'Load' and enter:"
    echo "     Module Name: OpenSC PKCS#11"
    echo "     Module Path: /usr/lib/opensc-pkcs11.so"
    echo ""
    
    print_info "Chrome/Chromium - Run this command:"
    echo "  modutil -dbdir sql:\$HOME/.pki/nssdb -add \"OpenSC\" -libfile /usr/lib/opensc-pkcs11.so"
    echo ""
    
    if [ "$CITRIX_MANUAL" != true ]; then
        echo "========================================="
        echo "  CITRIX CONFIGURATION"
        echo "========================================="
        echo ""
        
        print_info "Firefox - Configure ICA file handling:"
        echo "  1. Navigate to your LogonPoint portal"
        echo "  2. When prompted to open .ica file, select:"
        echo "     'Open with Citrix Workspace Engine'"
        echo "  3. Check 'Remember this choice'"
        echo ""
        echo "  OR manually configure:"
        echo "  Settings → General → Files and Applications"
        echo "  Find 'ICA' → Set to 'Open with Citrix Workspace Engine'"
        echo ""
        
        print_info "First-time connection:"
        echo "  1. Insert your CAC"
        echo "  2. Navigate to your organization's portal"
        echo "  3. Enter PIN when prompted"
        echo "  4. Allow .ica file to open with Citrix"
        echo "  5. Your virtual desktop/apps will launch"
    fi
}

# Main execution
main() {
    echo "========================================="
    echo "  CAC Reader & Citrix Workspace Setup"
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
    
    # Ask about Citrix installation
    read -p "Install Citrix Workspace? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        SKIP_CITRIX=true
    fi
    
    echo ""
    install_cac_packages
    
    if [ "$SKIP_CITRIX" != true ]; then
        install_citrix
    fi
    
    configure_pcscd
    configure_permissions
    test_setup
    configuration_instructions
    
    echo ""
    if [ "$NEED_LOGOUT" = true ]; then
        echo -e "${YELLOW}⚠ You must log out and back in for group changes to take effect${NC}"
    fi
    
    echo ""
    print_success "Setup complete!"
    echo ""
    
    if [ "$CITRIX_MANUAL" = true ]; then
        print_warning "Don't forget to manually install Citrix Workspace (see instructions above)"
    fi
}

# Run main function
main
