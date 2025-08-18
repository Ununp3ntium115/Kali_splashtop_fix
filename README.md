# Splashtop Streamer for Kali Linux (DEB, AMD64)

## Kali Linux Compatibility

This repository contains a **modified version** of the Splashtop Streamer specifically adapted for **Kali Linux compatibility**. The original Ubuntu package has been repackaged with the following enhancements:

### ✅ **Supported Versions**
- **Kali Linux 2025.2** (Latest - Fully Tested)
- **Kali Linux 2025.1** and newer
- **Debian Unstable** based distributions

### 🔧 **Key Modifications**
- **Updated Dependencies**: Added alternatives for newer library versions (fuse3, libgcc-s1, webkit variants)
- **Enhanced Display Manager Support**: 
  - GDM3 (GNOME 48 in Kali 2025.2)
  - LightDM (common in Xfce 4.20.4 - default in Kali)
  - SDDM (KDE Plasma 6.3 support)
- **Improved SystemD Service**: Better user management, logging, and restart behavior
- **Kali-Specific Installation Logic**: Handles Kali Linux environment differences

## Package Versions

### For Kali Linux (Recommended):
```bash
sudo apt update
sudo dpkg -i Splashtop_Streamer_Kali_amd64.deb
sudo apt-get install -f  # Fix any remaining dependencies
```

### For Ubuntu/Standard Debian:
```bash
sudo apt update  
sudo apt install ./Splashtop_Streamer_Ubuntu_amd64.deb
```

## Show command line usage

    splashtop-streamer help

## Deploy

    splashtop-streamer deploy $DEPLOYMENT_CODE

## Show configuration options

    splashtop-streamer config

## Uninstall

    sudo apt remove splashtop-streamer

## Verification & Troubleshooting

### Verify Installation on Kali 2025.2:
```bash
# Check Kali version
cat /etc/os-release | grep VERSION_ID
# Should show: VERSION_ID="2025.2"

# Verify service status
sudo systemctl status SRStreamer.service

# Test application
splashtop-streamer --version
```

### Common Issues:
```bash
# If you get "policykit-1 does not have an installable package" error:
./fix-dependencies.sh

# If other dependencies are missing:
sudo apt-get install -f

# Check service logs:
sudo journalctl -u SRStreamer.service

# Restart service:
sudo systemctl restart SRStreamer.service
```

## SRStreamer.service Management

### Status
```bash
systemctl status SRStreamer.service
```

### Start
```bash
sudo systemctl start SRStreamer.service
# OR
sudo service SRStreamer start
```

### Stop
```bash
sudo systemctl stop SRStreamer.service  
# OR
sudo service SRStreamer stop
```

## 🛠️ Additional Kali Linux Scripts

This repository includes powerful setup scripts for enhanced Kali Linux functionality:

### 🔐 Root Access Enablement
```bash
# Enable root login for GUI and SSH
./scripts/enable-root-login.sh
```
**Features:**
- Enables root GUI login (GDM3, LightDM, SDDM support)  
- Configures SSH root access
- Sets up root desktop environment
- Includes security warnings and backup creation

### 🖥️ Windows RDP Client Setup
```bash  
# Setup RDP clients for connecting TO Windows machines
./scripts/setup-windows-rdp-client.sh
```
**Features:**
- Installs FreeRDP, Remmina, and RDP tools
- Creates connection scripts with advanced options
- Network RDP scanner for discovery
- Desktop shortcuts and command aliases
- Interactive connection wizard

### 🌐 Kali RDP Server Setup  
```bash
# Enable RDP server for remote access TO Kali Linux
./scripts/setup-kali-rdp-server.sh
```
**Features:**
- Full XRDP server installation and configuration
- Xfce desktop optimized for RDP sessions
- Audio redirection support
- Firewall configuration
- Connection management utilities
- Works with Windows Remote Desktop Connection

### 🚀 Quick Setup (All-in-One)
```bash
# Run all setup scripts in sequence
chmod +x scripts/*.sh

# Enable root access
./scripts/enable-root-login.sh

# Setup Windows RDP client  
./scripts/setup-windows-rdp-client.sh

# Setup Kali RDP server
./scripts/setup-kali-rdp-server.sh
```

## 💡 Use Cases

**Penetration Testing Lab:**
- Use Kali as RDP server for remote testing
- Connect to Windows targets via RDP clients
- Root access for full system control

**Remote Administration:**
- Access Kali Linux desktop from Windows
- Manage multiple Kali instances remotely
- Secure tunneling through SSH

**Mixed Environment:**
- Seamless integration between Windows/Kali
- Centralized remote desktop management
- Cross-platform compatibility

## Technical Details

For detailed modification information, installation troubleshooting, and technical specifications, see:
- **[KALI_INSTALL_GUIDE.md](./KALI_INSTALL_GUIDE.md)** - Complete installation guide
- **Scripts Directory**: `./scripts/` - Additional setup utilities
- **Modified Files**: `/extracted_deb/control/control`, `/extracted_deb/control/postinst`, `/extracted_deb/data/lib/systemd/system/SRStreamer.service`


