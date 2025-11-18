# CAC Reader Setup Guide for Linux
## Manual Installation and Configuration

- This guide walks through setting up an Identiv Smartfold SCR3500-C CAC reader on Linux systems, specifically Arch Linux and Ubuntu/Debian derivatives. Explicitly, this is intended for my workplace's specific Remote Electronic Access virtual machine/desktop system - although it could be applicable for other use cases. YMMV.  
- PLEASE NOTE: This has only been tested thusfar on Arch, and seems to only work for chromium-based browsers rather than firefox. I may work to test on more distros, and attempt to fix the browser requirement if the mood hits in future.
- Recommend following the steps precisely as listed in this README.

- As a side note, I am also figuring a couple of components of the setup aren't actually required, may look to remove them and re-test in future. 

---

## Prerequisites

- Issued CAC/smart card reader plugged into your system
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

### Run the setup script
```bash
chmod +x setup_cac_reader.sh
./setup_cac_reader.sh
```
Ensure you attend to this installation - password will be required, and install prompts will be actioned. Highly, highly recommend accepting all install prompts unless you are dead confident you already have the relevant packages installed. 

### Start and enable the service:
```bash
sudo systemctl start pcscd.socket
sudo systemctl enable pcscd.socket
```

**What this does:**
- `start`: Immediately starts the service
- `enable`: Configures the service to start automatically on boot

---

## Verifying Reader Detection

After installing packages and starting the daemon, verify your reader is properly detected.

### Recommended Method: Using pcsc_scan (Detailed)
```bash
pcsc_scan
```

**Expected output:**
- Reader name and manufacturer
- ATR (Answer To Reset) data if a card is inserted
- Real-time monitoring of card insertion/removal

Press `Ctrl+C` to exit when done.

**If you get "command not found":** Install pcsc-tools

## Browser Configuration

To use your CAC with web browsers, you need to configure the PKCS#11 security module. PLEASE NOTE: Firefox has not fully worked for me thusfar; I have only had complete success with Chromium. 

### Firefox (Seemingly not working - highly suggest the use of Chromium)

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

By default, `pcscd` runs continuously. For personal machines with occasional CAC use, you may prefer on-demand activation. If so, use this option below (it is also the same setup that I verified functionality with).

### Recommended Additional Configuration: On-Demand via Socket Activation (Recommended for Personal Use)

Service only starts when your CAC reader is accessed, then stops when idle.
```bash
# Stop and disable the always-running service
sudo systemctl stop pcscd.service
sudo systemctl disable pcscd.service

# Enable socket activation
sudo systemctl enable pcscd.socket
sudo systemctl start pcscd.socket
```

**Check socket status:**
```bash
systemctl status pcscd.socket
```

---

## Troubleshooting

### Start an Issue
I have not fully tested most configurations - besides the one specific configuration as detailed throughout the entirety of this README. I recommend following these recommendations to a tee, first. However, feel free to raise an issue if this doesn't work, or if an alternative configuration doesn't work for you - I will do my best to sort this.

---

## Additional Resources

**OpenSC Documentation:** https://github.com/OpenSC/OpenSC/wiki

**PC/SC Lite:** https://pcsclite.apdu.fr/

**Arch Wiki - Smart Cards:** https://wiki.archlinux.org/title/Smartcards

---

## Security Notes

- Never share your DCAC PIN with anyone
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
Run the uninstall script:

```bash
chmod +x uninstall_cac_reader.sh
./uninstall_cac_reader.sh
```

### Browser cleanup

**Firefox:** Go to Security Devices and unload the OpenSC module. Again, at this date I have not been able to get Firefox to work all the way through so Chromium is by far the best option for installation. 

**Chrome:**
```bash
modutil -dbdir sql:$HOME/.pki/nssdb -delete "OpenSC"
```

---

**Document Version:** 1.0  
**Last Updated:** November 2025  
**Tested On:** Arch Linux
**Any troubles, please feel free to raise an issue**
