# Splashtop Streamer for Kali Linux 2025.2

A comprehensive solution for installing and configuring Splashtop Streamer on Kali Linux 2025.2 amd64, with additional RDP functionality and troubleshooting tools.

## 🚀 Quick Start

**One-command installation:**
```bash
sudo ./install-master.sh
```

This master script handles everything automatically:
- ✅ Splashtop Streamer installation with Kali Linux compatibility fixes
- ✅ Dependency resolution and library path configuration  
- ✅ Service permissions and binary executable fixes
- ✅ UFW firewall rules for remote access
- ✅ Root access enablement and RDP server setup
- ✅ Comprehensive troubleshooting tools

## 📦 What's Included

### Core Package
- **`Splashtop_Streamer_Kali_amd64.deb`** - Modified Splashtop package with Kali Linux 2025.2 dependencies
- **`deb_extractor.py`** - Custom extraction tool for .deb packages  
- **`rebuild_deb.py`** - Package rebuilding script with GNU tar format compatibility

### Setup Scripts
- **`install-master.sh`** - Master installation script (recommended)
- **`scripts/enable-root-login.sh`** - Enable root desktop login for multiple display managers
- **`scripts/setup-windows-rdp-client.sh`** - Configure FreeRDP and Remmina for Windows RDP connections
- **`scripts/setup-kali-rdp-server.sh`** - Install and configure XRDP server for incoming connections
- **`scripts/master-setup.sh`** - Interactive setup coordinator for all additional functionality

### Fix Scripts
- **`fix-library-path.sh`** - Resolves missing library issues and binary permissions
- **`fix-dependencies.sh`** - Automated dependency resolution for Kali Linux
- **`install-fallback.sh`** - Alternative installation method for problematic systems

### Troubleshooting Toolkit
- **`troubleshooting/master-troubleshoot.sh`** - Interactive diagnostic coordinator
- **`troubleshooting/crash-analyzer.sh`** - Specialized crash investigation with core dump analysis
- **`troubleshooting/system-diagnostic.sh`** - Complete system health assessment  
- **`troubleshooting/splashtop-diagnostic.sh`** - Service-specific diagnostics
- **`troubleshooting/network-diagnostic.sh`** - Network connectivity and firewall analysis
- **`troubleshooting/log-analyzer.sh`** - Intelligent log analysis with pattern recognition
- **`troubleshooting/dependency-check.sh`** - Comprehensive dependency verification

## 🔧 Installation Methods

### Method 1: Master Installation (Recommended)
```bash
git clone https://github.com/Ununp3ntium115/Kali_splashtop_fix.git
cd Kali_splashtop_fix
sudo ./install-master.sh
```

### Method 2: Manual Step-by-Step
```bash
# 1. Install Splashtop package
sudo dpkg -i Splashtop_Streamer_Kali_amd64.deb

# 2. Fix any dependency issues
sudo ./fix-dependencies.sh

# 3. Fix library paths and permissions
sudo ./fix-library-path.sh

# 4. Configure additional features (optional)
./scripts/master-setup.sh
```

### Method 3: Fallback Installation
```bash
# If standard installation fails
sudo ./install-fallback.sh
```

## 🛠️ System Requirements

- **OS:** Kali Linux 2025.2 amd64
- **Memory:** 2GB+ RAM recommended
- **Network:** Internet connection for dependency installation
- **Display:** X11 or Wayland display server
- **User:** sudo privileges required for installation

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

# If you get "corrupted filesystem tarfile" or PAX header errors:
./install-fallback.sh

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


