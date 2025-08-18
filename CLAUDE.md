# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a modified Splashtop Streamer package specifically adapted for **Kali Linux 2025.2 compatibility**, along with comprehensive setup scripts for creating a complete remote desktop environment. The project transforms the original Ubuntu-targeted package into a Kali Linux-optimized solution with additional RDP functionality.

## Core Architecture

### Package Modification Pipeline
The project uses a **extract → modify → rebuild** approach for .deb package customization:

1. **Extraction**: `deb_extractor.py` - Custom Python AR archive parser that extracts .deb files into structured directories
2. **Modification**: Manual editing of control files, systemd services, and installation scripts in `extracted_deb/`
3. **Rebuilding**: `rebuild_deb.py` - Reconstructs modified .deb packages with proper AR archive format

### Key Components Architecture

**Modified Splashtop Package** (`Splashtop_Streamer_Kali_amd64.deb`):
- **Control System**: `extracted_deb/control/` contains package metadata, installation/removal scripts
- **Data Payload**: `extracted_deb/data/` mirrors the target filesystem structure
- **Service Configuration**: Enhanced systemd service with user isolation and improved logging
- **Display Manager Integration**: Multi-DM support (GDM3, LightDM, SDDM) with Kali-specific logic

**Setup Scripts Ecosystem** (`scripts/`):
- **Master Controller**: `master-setup.sh` orchestrates all installations with interactive menus and comprehensive logging
- **Modular Components**: Each script handles a specific domain (root access, RDP client tools, RDP server setup)
- **State Management**: Scripts create backups, verify prerequisites, and provide rollback capabilities

## Essential Commands

### Package Development Workflow
```bash
# Extract original Ubuntu package for modification
python3 deb_extractor.py

# After modifying files in extracted_deb/, rebuild Kali package
python3 rebuild_deb.py

# Test package installation on Kali Linux
sudo dpkg -i Splashtop_Streamer_Kali_amd64.deb
sudo apt-get install -f  # Fix dependencies
```

### Setup Script Operations
```bash
# Make all scripts executable
chmod +x scripts/*.sh

# Run complete system setup with interactive menu
./scripts/master-setup.sh

# Individual component setup
./scripts/enable-root-login.sh          # Root GUI/SSH access
./scripts/setup-windows-rdp-client.sh   # RDP client tools
./scripts/setup-kali-rdp-server.sh      # XRDP server setup
```

### Service Management and Diagnostics
```bash
# Splashtop Streamer service management
sudo systemctl status SRStreamer.service
sudo systemctl restart SRStreamer.service
sudo journalctl -u SRStreamer.service -f

# Verify Kali compatibility
cat /etc/os-release | grep VERSION_ID    # Should show "2025.2"
splashtop-streamer --version
which splashtop-streamer

# RDP server management (after setup)
xrdp-status     # Check XRDP server status
xrdp-manage     # Interactive XRDP management
xrdp-restart    # Restart XRDP services
```

### Package Modification Guidelines

**Control File Modifications** (`extracted_deb/control/control`):
- Version must follow `X.X.X.X-XkaliY` format for Kali packages
- Dependencies use `|` alternatives for compatibility with newer library versions
- Maintainer field should reference "Kali Linux Team" with original maintainer preserved

**Installation Script Patterns** (`extracted_deb/control/postinst`):
- Display manager detection uses conditional blocks for GDM3, LightDM, SDDM
- Kali-specific configurations are isolated in separate conditional sections
- All system modifications create backup files with timestamps

**Service Configuration** (`extracted_deb/data/lib/systemd/system/SRStreamer.service`):
- User/Group isolation with dedicated `splashtop-streamer` account
- Enhanced restart policies with RestartSec and KillMode settings
- Multiple target dependencies for GUI environment compatibility

## Package Dependencies Architecture

The modified package uses **alternative dependency chains** to handle library variations across Debian unstable (Kali base):
- Modern alternatives listed first: `libgcc-s1 | libgcc1`, `fuse | fuse3`
- WebKit variants cover different GTK versions: `libwebkit2gtk-4.1-0 | libwebkit2gtk-4.0-37 | libwebkit2gtk-4.0-dev`
- Display manager compatibility through proxy libraries: `libproxy1v5 | libproxy1-plugin-gsettings`

## Script Logging and Error Handling

All setup scripts implement standardized patterns:
- **Logging Function**: `log_message()` with timestamps saved to `$HOME/kali-setup-TIMESTAMP.log`
- **Prerequisite Checks**: Kali Linux detection, permission verification, service availability
- **Backup Strategy**: Configuration files backed up with `.backup.TIMESTAMP` extension
- **Interactive Prompts**: User confirmation for security-sensitive operations with default-safe options

## Integration Points

**Display Manager Detection Logic**:
Scripts detect active display managers through `systemctl is-active` and configuration file presence, then apply appropriate modifications for each DM type.

**Network Service Configuration**:
RDP server setup integrates with system firewall (UFW/iptables), configures audio redirection through PulseAudio modules, and creates management utilities with desktop integration.

**Cross-Platform Compatibility**:
Windows RDP client tools include protocol detection, connection profiling, and network discovery capabilities that work seamlessly with both Windows targets and the configured Kali RDP server.