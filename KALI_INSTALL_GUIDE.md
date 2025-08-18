# Splashtop Streamer for Kali Linux Installation Guide

## Package Information
- **Original Package**: Splashtop_Streamer_Ubuntu_amd64.deb (v3.7.4.0-1)
- **Modified Package**: Splashtop_Streamer_Kali_amd64.deb (v3.7.4.0-1kali1)
- **Architecture**: amd64
- **Compatible with**: Kali Linux (Debian unstable based)

## Key Modifications for Kali Linux

### 1. Updated Dependencies
- Added alternative packages for newer library versions
- Added support for fuse3 alongside fuse2
- Updated libgcc dependencies for newer systems
- Added webkit alternatives for compatibility

### 2. Display Manager Support
- Enhanced support for GDM3 (standard Ubuntu/Debian)
- Added LightDM configuration (common in Kali Linux)
- Added SDDM detection and support
- Improved Wayland/X11 session handling

### 3. Systemd Service Improvements
- Added proper user/group execution
- Enhanced restart behavior
- Better logging configuration
- Added graphical target dependency

### 4. Installation Scripts
- Enhanced postinst script with Kali Linux specific logic
- Better error handling
- Improved display manager detection

## Installation Instructions

### Prerequisites
```bash
# Update package lists
sudo apt update

# Install required dependencies (most should already be available)
sudo apt install -y curl fuse pulseaudio-utils polkitd x11-xserver-utils xinput
```

### Install the Package
```bash
# Install the Kali Linux compatible package
sudo dpkg -i Splashtop_Streamer_Kali_amd64.deb

# If there are dependency issues, fix them with:
sudo apt-get install -f
```

### Verify Installation
```bash
# Check if the service is running
sudo systemctl status SRStreamer.service

# Check if the binary is accessible
which splashtop-streamer

# Test the application
splashtop-streamer --version
```

## Troubleshooting

### Common Issues

1. **Service fails to start**
   ```bash
   sudo journalctl -u SRStreamer.service
   sudo systemctl restart SRStreamer.service
   ```

2. **Missing dependencies**
   ```bash
   sudo apt-get install -f
   sudo apt update && sudo apt upgrade
   ```

3. **Display manager issues**
   ```bash
   # Check which display manager is running
   sudo systemctl status display-manager

   # For LightDM users, check configuration
   ls -la /etc/lightdm/lightdm.conf.d/95-splashtop.conf
   ```

4. **Permission issues**
   ```bash
   # Verify user and group creation
   id splashtop-streamer
   ls -la /opt/splashtop-streamer/
   ```

### Uninstallation
```bash
sudo systemctl stop SRStreamer.service
sudo systemctl disable SRStreamer.service
sudo dpkg -r splashtop-streamer
```

## Notes
- The package maintains compatibility with the original Splashtop functionality
- All original files and permissions are preserved
- The service runs under a dedicated `splashtop-streamer` user for security
- Reboot may be required if display manager settings were modified

## File Locations
- **Main Installation**: `/opt/splashtop-streamer/`
- **Service File**: `/lib/systemd/system/SRStreamer.service`
- **User Binary**: `/usr/bin/splashtop-streamer`
- **Desktop Files**: `/usr/share/applications/com.splashtop.streamer*.desktop`
- **Configuration**: `/opt/splashtop-streamer/config/`
- **Logs**: `/opt/splashtop-streamer/log/`