#!/bin/bash
# Dependency Fix Script for Kali Linux 2025.2
# Resolves common package name changes in newer Debian/Kali versions

set -e

echo "========================================"
echo "  Kali Linux Dependency Fix Script"
echo "========================================"
echo ""

# Check if running on Kali Linux
if ! grep -q "kali" /etc/os-release 2>/dev/null; then
    echo "⚠️  Warning: This script is designed for Kali Linux."
fi

echo "🔧 This script will fix common dependency issues:"
echo "   - Install current PolicyKit package (polkitd)"
echo "   - Update package lists"
echo "   - Install missing dependencies for Splashtop"
echo ""

# Update package lists
echo "📦 Updating package lists..."
sudo apt update

# Install PolicyKit with current package name
echo "🔐 Installing PolicyKit (polkitd)..."
if ! dpkg -l | grep -q "^ii.*polkitd"; then
    sudo apt install -y polkitd
    echo "✅ PolicyKit installed successfully"
else
    echo "✅ PolicyKit already installed"
fi

# Install other common dependencies that might be missing
echo "📦 Installing other common dependencies..."
sudo apt install -y \
    curl \
    fuse \
    pulseaudio-utils \
    x11-xserver-utils \
    xinput \
    bash-completion \
    lshw \
    util-linux \
    zip \
    adduser

echo "✅ All dependencies installed successfully"
echo ""

# Try to fix any broken dependencies
echo "🔧 Fixing any broken dependencies..."
sudo apt-get install -f

echo ""
echo "========================================"
echo "✅ Dependency fix completed!"
echo "========================================"
echo ""
echo "💡 You can now try installing the Splashtop package:"
echo "   sudo dpkg -i Splashtop_Streamer_Kali_amd64.deb"
echo "   sudo apt-get install -f  # If there are still issues"
echo ""