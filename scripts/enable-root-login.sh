#!/bin/bash
# Kali Linux Root Login Enablement Script
# Enables root login for GUI and SSH access

set -e

echo "========================================"
echo "    Kali Linux Root Login Enabler"
echo "========================================"

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "❌ This script should NOT be run as root. Please run as regular user with sudo privileges."
    exit 1
fi

# Check if running on Kali Linux
if ! grep -q "kali" /etc/os-release 2>/dev/null; then
    echo "⚠️  Warning: This script is designed for Kali Linux. Continue anyway? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 1
    fi
fi

echo "🔐 This script will enable root login for:"
echo "   - GUI (Display Manager)"
echo "   - SSH Access"
echo "   - Terminal Access"
echo ""
echo "⚠️  WARNING: Enabling root login reduces security!"
echo "   Only enable this in controlled environments."
echo ""
read -p "Continue? (y/N): " -r
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Exiting..."
    exit 1
fi

# Set root password if not already set
echo ""
echo "🔑 Setting root password..."
if sudo passwd -S root 2>/dev/null | grep -q "L"; then
    echo "Root account is locked. Setting password..."
    sudo passwd root
else
    echo "Root password is already set."
    read -p "Change root password? (y/N): " -r
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        sudo passwd root
    fi
fi

# Enable root login for SSH
echo ""
echo "🌐 Configuring SSH for root login..."
SSH_CONFIG="/etc/ssh/sshd_config"
if [[ -f "$SSH_CONFIG" ]]; then
    # Backup original config
    sudo cp "$SSH_CONFIG" "$SSH_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Enable root login
    if grep -q "^#PermitRootLogin" "$SSH_CONFIG"; then
        sudo sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' "$SSH_CONFIG"
    elif grep -q "^PermitRootLogin" "$SSH_CONFIG"; then
        sudo sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' "$SSH_CONFIG"
    else
        echo "PermitRootLogin yes" | sudo tee -a "$SSH_CONFIG" > /dev/null
    fi
    
    # Enable password authentication
    if grep -q "^#PasswordAuthentication" "$SSH_CONFIG"; then
        sudo sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' "$SSH_CONFIG"
    elif grep -q "^PasswordAuthentication" "$SSH_CONFIG"; then
        sudo sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/' "$SSH_CONFIG"
    else
        echo "PasswordAuthentication yes" | sudo tee -a "$SSH_CONFIG" > /dev/null
    fi
    
    echo "✅ SSH configured for root login"
    
    # Start and enable SSH service
    sudo systemctl enable ssh
    sudo systemctl restart ssh
    echo "✅ SSH service enabled and started"
else
    echo "⚠️  SSH config not found. Installing SSH..."
    sudo apt update
    sudo apt install -y openssh-server
    sudo systemctl enable ssh
    sudo systemctl start ssh
    echo "✅ SSH installed and configured"
fi

# Configure display manager for root login
echo ""
echo "🖥️  Configuring display manager for root login..."

# GDM3 Configuration
if systemctl is-active --quiet gdm3 || [[ -f "/etc/gdm3/daemon.conf" ]]; then
    echo "Configuring GDM3..."
    GDM_CONFIG="/etc/gdm3/daemon.conf"
    if [[ -f "$GDM_CONFIG" ]]; then
        sudo cp "$GDM_CONFIG" "$GDM_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Enable root login in GDM3
        if ! grep -q "\[security\]" "$GDM_CONFIG"; then
            echo -e "\n[security]" | sudo tee -a "$GDM_CONFIG" > /dev/null
        fi
        
        if ! grep -q "AllowRoot" "$GDM_CONFIG"; then
            sudo sed -i '/\[security\]/a AllowRoot=true' "$GDM_CONFIG"
        else
            sudo sed -i 's/^#\?AllowRoot=.*/AllowRoot=true/' "$GDM_CONFIG"
        fi
        
        echo "✅ GDM3 configured for root login"
    fi
fi

# LightDM Configuration
if systemctl is-active --quiet lightdm || [[ -f "/etc/lightdm/lightdm.conf" ]]; then
    echo "Configuring LightDM..."
    LIGHTDM_CONFIG="/etc/lightdm/lightdm.conf"
    if [[ -f "$LIGHTDM_CONFIG" ]]; then
        sudo cp "$LIGHTDM_CONFIG" "$LIGHTDM_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Enable root login in LightDM
        if ! grep -q "greeter-show-manual-login=true" "$LIGHTDM_CONFIG"; then
            sudo sed -i '/\[Seat:\*\]/a greeter-show-manual-login=true' "$LIGHTDM_CONFIG"
        fi
        
        echo "✅ LightDM configured for root login"
    fi
fi

# SDDM Configuration  
if systemctl is-active --quiet sddm || [[ -f "/etc/sddm.conf" ]]; then
    echo "Configuring SDDM..."
    SDDM_CONFIG="/etc/sddm.conf"
    if [[ ! -f "$SDDM_CONFIG" ]]; then
        sudo mkdir -p /etc/sddm.conf.d/
        SDDM_CONFIG="/etc/sddm.conf.d/root-login.conf"
    fi
    
    sudo cp "$SDDM_CONFIG" "$SDDM_CONFIG.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    
    # SDDM allows root login by default, but ensure it's not disabled
    if ! grep -q "\[Theme\]" "$SDDM_CONFIG" 2>/dev/null; then
        echo -e "[Theme]\n# Root login enabled\n" | sudo tee "$SDDM_CONFIG" > /dev/null
    fi
    
    echo "✅ SDDM configured for root login"
fi

# Configure PAM for root login (if needed)
echo ""
echo "🔐 Configuring PAM for root access..."
PAM_GDM="/etc/pam.d/gdm-password"
if [[ -f "$PAM_GDM" ]]; then
    # Comment out root login restrictions
    if grep -q "pam_succeed_if.so user != root quiet_success" "$PAM_GDM"; then
        sudo sed -i 's/^auth.*pam_succeed_if.so user != root quiet_success/#&/' "$PAM_GDM"
        echo "✅ PAM configured to allow root GUI login"
    fi
fi

# Create root desktop shortcuts
echo ""
echo "🔗 Creating root desktop environment..."
if [[ ! -d "/root/Desktop" ]]; then
    sudo mkdir -p /root/Desktop
    sudo mkdir -p /root/.config
    echo "✅ Root desktop directories created"
fi

# Set proper permissions
echo ""
echo "🔧 Setting permissions..."
sudo chown -R root:root /root/
sudo chmod 700 /root/
echo "✅ Root directory permissions set"

# Display summary
echo ""
echo "========================================"
echo "✅ Root login configuration complete!"
echo "========================================"
echo ""
echo "📋 Summary of changes:"
echo "   ✅ Root password set/updated"
echo "   ✅ SSH root login enabled"
echo "   ✅ Display manager configured for root login"
echo "   ✅ PAM restrictions removed"
echo "   ✅ Root desktop environment prepared"
echo ""
echo "🔄 To apply all changes, please reboot or restart display manager:"
echo "   sudo systemctl restart display-manager"
echo ""
echo "🌐 SSH Access:"
echo "   ssh root@$(hostname -I | awk '{print $1}')"
echo ""
echo "⚠️  Security Notice:"
echo "   Root login is now enabled. Consider:"
echo "   - Using strong passwords"
echo "   - Limiting SSH access with firewall rules"
echo "   - Using SSH keys instead of passwords"
echo "   - Monitoring login attempts"
echo ""
echo "🔙 To revert changes, restore backup files:"
echo "   ls /etc/ssh/sshd_config.backup.*"
echo "   ls /etc/gdm3/daemon.conf.backup.* 2>/dev/null || true"
echo "   ls /etc/lightdm/lightdm.conf.backup.* 2>/dev/null || true"