# CAC Reader Setup Guide for Linux
## Manual Installation and Configuration

This guide walks through setting up an Identiv Smartfold SCR3500-C CAC reader (or similar smart card readers) on Linux systems, specifically Arch Linux and Ubuntu/Debian derivatives.

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Verifying Hardware Detection](#verifying-hardware-detection)
3. [Installing Required Packages](#installing-required-packages)
4. [Configuring the PC/SC Daemon](#configuring-the-pcsc-daemon)
5. [Verifying Reader Detection](#verifying-reader-detection)
6. [Browser Configuration](#browser-configuration)
7. [Service Management Options](#service-management-options)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- A CAC/smart card reader plugged into your system
- Admin/sudo access
- Internet connection for package installation

---

## Verifying Hardware Detection

Before installing software, verify your CAC reader is detected by the system:
```bash
lsusb
```

You should see an entry for your reader. For the Identiv SCR3500-C, it appears as:
```
Bus 001 Device 013: ID 04e6:581d SCM Microsystems, Inc. SCR3500 C Contact Reader
```

The specific bus and device numbers will vary, but the vendor ID (04e6) and product ID (581d) identify the device.

---

## Installing Required Packages

### Arch Linux
```bash
sudo pacman -S pcsclite ccid opensc pcsc-tools
```

**Package descriptions:**
- **pcsclite**: PC/SC middleware that provides smart card support
- **ccid**: Driver for CCID-compliant smart card readers (your SCR3500 is CCID-compliant)
- **opensc**: Smart card utilities and PKCS#11 module for cryptographic operations
- **pcsc-tools**: Diagnostic and testing tools for smart card readers

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install pcscd libccid opensc pcsc-tools
```

---

## Configuring the PC/SC Daemon

The PC/SC daemon (pcscd) handles communication between your system and the smart card reader.

### Start and enable the service:
```bash
sudo systemctl start pcscd.service
sudo systemctl enable pcscd.service
```

**What this does:**
- `start`: Immediately starts the service
- `enable`: Configures the service to start automatically on boot

### Check service status:
```bash
systemctl status pcscd
```

You should see output indicating the service is "active (running)".

---

## Verifying Reader Detection

After installing packages and starting the daemon, verify your reader is properly detected.

### Method 1: Using pcsc_scan (Detailed)
```bash
pcsc_scan
```

**Expected output:**
- Reader name and manufacturer
- ATR (Answer To Reset) data if a card is inserted
- Real-time monitoring of card insertion/removal

Press `Ctrl+C` to exit when done.

**If you get "command not found":** Install pcsc-tools (see [Installing Required Packages](#installing-required-packages))

### Method 2: Using opensc-tool (Quick check)
```bash
opensc-tool --list-readers
```

This provides a simple list of detected readers without continuous monitoring.

---

## Browser Configuration

To use your CAC with web browsers, you need to configure the PKCS#11 security module.

### Firefox

1. Open Firefox
2. Navigate to `about:preferences#privacy`
3. Scroll down to the "Certificates" section
4. Click **"Security Devices"**
5. Click **"Load"**
6. Enter the following information:
   - **Module Name:** `OpenSC PKCS#11`
   - **Module filename:** `/usr/lib/opensc-pkcs11.so`
7. Click **OK**

**Verification:**
- Insert your CAC
- Navigate to your organization's portal
- You should be prompted to select a certificate and enter your PIN

### Chrome/Chromium

Chrome uses the NSS database for certificate management. Configure it via command line:
```bash
modutil -dbdir sql:$HOME/.pki/nssdb -add "OpenSC" -libfile /usr/lib/opensc-pkcs11.so
```

**To verify:**
```bash
modutil -dbdir sql:$HOME/.pki/nssdb -list
```

You should see "OpenSC" listed under security modules.

**To remove (if needed):**
```bash
modutil -dbdir sql:$HOME/.pki/nssdb -delete "OpenSC"
```

---

## Service Management Options

By default, `pcscd` runs continuously. For personal machines with occasional CAC use, you may prefer on-demand activation.

### Option 1: Always Running (Default)

Service runs continuously in the background.
```bash
sudo systemctl enable pcscd.service
sudo systemctl start pcscd.service
```

**Pros:**
- Instant response when inserting CAC
- Simple configuration

**Cons:**
- Uses system resources even when not needed
- Slightly larger attack surface

### Option 2: On-Demand via Socket Activation (Recommended for Personal Use)

Service only starts when your CAC reader is accessed, then stops when idle.
```bash
# Stop and disable the always-running service
sudo systemctl stop pcscd.service
sudo systemctl disable pcscd.service

# Enable socket activation
sudo systemctl enable pcscd.socket
sudo systemctl start pcscd.socket
```

**Pros:**
- Saves resources when not in use
- Reduced attack surface
- Automatic start when needed

**Cons:**
- Slight delay (1-2 seconds) on first access

**Check socket status:**
```bash
systemctl status pcscd.socket
```

---

## Troubleshooting

### Reader not detected

**Check USB connection:**
```bash
lsusb
```

Verify your reader appears in the output.

**Restart the PC/SC daemon:**
```bash
sudo systemctl restart pcscd
```

**Check for permission issues:**

Some systems require users to be in the `pcscd` group:
```bash
# Check if group exists and if you're a member
groups $USER

# Add yourself to the group if needed
sudo usermod -aG pcscd $USER
```

**Important:** Log out and back in for group changes to take effect.

### Browser doesn't recognize certificates

**Verify PKCS#11 module is loaded:**

In Firefox, go to `about:preferences#privacy` → Security Devices and confirm "OpenSC PKCS#11" is listed.

**Check card is detected:**
```bash
pkcs11-tool --list-slots
```

You should see your reader listed with a token present.

**View certificates on card:**
```bash
pkcs11-tool --list-objects
```

### PIN prompt doesn't appear

**Verify the card is detected:**
```bash
pcsc_scan
```

With your CAC inserted, you should see card details.

**Check browser console:**
- Firefox: `Ctrl+Shift+K` → Look for security/certificate errors
- Chrome: `Ctrl+Shift+J` → Check for PKCS#11 related errors

### Service fails to start

**Check logs:**
```bash
journalctl -u pcscd -n 50
```

**Common issues:**
- Conflicting drivers (check for other smart card software)
- Permissions on `/var/run/pcscd/` directory
- Reader firmware issues (try unplugging and replugging)

---

## Additional Resources

**OpenSC Documentation:** https://github.com/OpenSC/OpenSC/wiki

**PC/SC Lite:** https://pcsclite.apdu.fr/

**Arch Wiki - Smart Cards:** https://wiki.archlinux.org/title/Smartcards

---

## Security Notes

- Never share your CAC PIN with anyone
- Keep your CAC reader drivers updated
- Use socket activation on personal devices to minimize exposure
- Remove the PKCS#11 module from browsers when not needed for extended periods

---

## Uninstalling

If you need to remove CAC reader support:

### Stop services
```bash
sudo systemctl stop pcscd.socket
sudo systemctl disable pcscd.socket
sudo systemctl stop pcscd.service
sudo systemctl disable pcscd.service
```

### Remove packages

**Arch Linux:**
```bash
sudo pacman -Rns pcsclite ccid opensc pcsc-tools
```

**Ubuntu/Debian:**
```bash
sudo apt remove --purge pcscd libccid opensc pcsc-tools
sudo apt autoremove
```

### Remove from group
```bash
sudo gpasswd -d $USER pcscd
```

### Browser cleanup

**Firefox:** Go to Security Devices and unload the OpenSC module

**Chrome:**
```bash
modutil -dbdir sql:$HOME/.pki/nssdb -delete "OpenSC"
```

---

**Document Version:** 1.0  
**Last Updated:** November 2025  
**Tested On:** Arch Linux
