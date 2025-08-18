#!/bin/bash
# Fallback installation script for Splashtop Streamer on Kali Linux
# Uses original Ubuntu package with manual fixes if Kali package fails

set -e

echo "========================================"
echo "  Splashtop Fallback Installation"
echo "========================================"
echo ""

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
KALI_DEB="$SCRIPT_DIR/Splashtop_Streamer_Kali_amd64.deb"
UBUNTU_DEB="$SCRIPT_DIR/Splashtop_Streamer_Ubuntu_amd64.deb"

# Check if running on Kali Linux
if ! grep -q "kali" /etc/os-release 2>/dev/null; then
    echo "⚠️  Warning: This script is designed for Kali Linux."
    read -p "Continue anyway? (y/N): " -r
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 1
    fi
fi

# Function to install dependencies
install_dependencies() {
    echo "📦 Installing/updating dependencies..."
    
    # Fix dependencies first
    if [[ -x "$SCRIPT_DIR/fix-dependencies.sh" ]]; then
        echo "🔧 Running dependency fix script..."
        "$SCRIPT_DIR/fix-dependencies.sh"
    else
        # Manual dependency installation
        sudo apt update
        sudo apt install -y \
            curl fuse pulseaudio-utils polkitd \
            x11-xserver-utils xinput bash-completion \
            lshw util-linux zip adduser
    fi
}

# Function to try installing Kali package
try_kali_package() {
    if [[ -f "$KALI_DEB" ]]; then
        echo "📦 Attempting to install Kali-optimized package..."
        if sudo dpkg -i "$KALI_DEB" 2>/dev/null; then
            sudo apt-get install -f -y
            echo "✅ Kali package installed successfully!"
            return 0
        else
            echo "❌ Kali package installation failed"
            return 1
        fi
    else
        echo "⚠️  Kali package not found: $KALI_DEB"
        return 1
    fi
}

# Function to install Ubuntu package with manual fixes
install_ubuntu_fallback() {
    if [[ ! -f "$UBUNTU_DEB" ]]; then
        echo "❌ Ubuntu fallback package not found: $UBUNTU_DEB"
        return 1
    fi
    
    echo "📦 Installing Ubuntu package as fallback..."
    
    # Install Ubuntu package
    if sudo dpkg -i "$UBUNTU_DEB"; then
        sudo apt-get install -f -y
        echo "✅ Ubuntu package installed"
    else
        echo "❌ Ubuntu package installation also failed"
        return 1
    fi
    
    # Apply Kali-specific fixes manually
    echo "🔧 Applying Kali Linux compatibility fixes..."
    
    # Fix display manager configuration
    if [[ -e /etc/lightdm/lightdm.conf ]] || [[ -d /etc/lightdm/lightdm.conf.d/ ]]; then
        echo "🖥️  Configuring LightDM for Kali Linux..."
        if [[ -d /etc/lightdm/lightdm.conf.d/ ]]; then
            sudo tee /etc/lightdm/lightdm.conf.d/95-splashtop.conf > /dev/null << 'EOF'
[Seat:*]
greeter-show-manual-login=true
EOF
            echo "✅ LightDM configured"
        fi
    fi
    
    # Enhance systemd service
    echo "⚙️  Updating systemd service for better compatibility..."
    sudo tee /lib/systemd/system/SRStreamer.service > /dev/null << 'EOF'
[Unit]
Description=Splashtop Streamer Daemon
Wants=network-online.target
After=network.target network-online.target graphical-session.target
Requisite=network.target

[Service]
Environment="LD_LIBRARY_PATH=/opt/splashtop-streamer"
Type=simple
User=splashtop-streamer
Group=splashtop-streamer
PIDFile=/run/SRStreamer.pid
ExecStart=/opt/splashtop-streamer/SRFeature
Restart=always
RestartSec=5
TimeoutStopSec=30
KillMode=mixed
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target graphical.target
EOF
    
    # Reload systemd
    sudo systemctl daemon-reload
    
    echo "✅ Manual Kali Linux fixes applied"
    return 0
}

# Function to verify installation
verify_installation() {
    echo "🔍 Verifying installation..."
    
    # Check if binary exists
    if command -v splashtop-streamer &> /dev/null; then
        echo "✅ splashtop-streamer binary found"
    else
        echo "❌ splashtop-streamer binary not found"
        return 1
    fi
    
    # Check service
    if systemctl list-unit-files | grep -q SRStreamer.service; then
        echo "✅ SRStreamer service file found"
        
        # Try to start service
        if sudo systemctl enable SRStreamer.service && sudo systemctl start SRStreamer.service; then
            echo "✅ Service started successfully"
        else
            echo "⚠️  Service failed to start - check logs: sudo journalctl -u SRStreamer.service"
        fi
    else
        echo "❌ SRStreamer service not found"
        return 1
    fi
    
    return 0
}

# Main installation process
echo "🚀 Starting fallback installation process..."
echo ""

# Step 1: Install dependencies
install_dependencies

echo ""

# Step 2: Try Kali package first
echo "📦 Step 1: Trying Kali-optimized package..."
if try_kali_package; then
    INSTALL_METHOD="kali"
else
    echo ""
    echo "📦 Step 2: Trying Ubuntu package with manual fixes..."
    if install_ubuntu_fallback; then
        INSTALL_METHOD="ubuntu-fallback"
    else
        echo ""
        echo "❌ Both installation methods failed!"
        echo "Please check the error messages above and try manual installation."
        exit 1
    fi
fi

echo ""

# Step 3: Verify installation
if verify_installation; then
    echo ""
    echo "========================================"
    echo "✅ Installation completed successfully!"
    echo "========================================"
    echo ""
    echo "📋 Installation method: $INSTALL_METHOD"
    echo "🌐 Service status: $(sudo systemctl is-active SRStreamer.service 2>/dev/null || echo 'inactive')"
    echo ""
    echo "💡 Usage:"
    echo "   splashtop-streamer help    # Show help"
    echo "   splashtop-streamer config  # Configuration"
    echo "   sudo systemctl status SRStreamer.service  # Check service"
    echo ""
    echo "📝 Logs: sudo journalctl -u SRStreamer.service -f"
else
    echo ""
    echo "⚠️  Installation completed but verification failed"
    echo "Please check the service manually:"
    echo "   sudo systemctl status SRStreamer.service"
    echo "   sudo journalctl -u SRStreamer.service"
fi