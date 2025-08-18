#!/bin/bash
# Kali Linux RDP Server Setup Script
# Enables remote desktop access TO Kali Linux from Windows/other RDP clients

set -e

echo "========================================"
echo "   Kali Linux RDP Server Setup"
echo "========================================"

# Check if running on Kali Linux
if ! grep -q "kali" /etc/os-release 2>/dev/null; then
    echo "⚠️  Warning: This script is designed for Kali Linux. Continue anyway? (y/N)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 1
    fi
fi

echo "🖥️  This script will set up RDP server on Kali Linux to allow:"
echo "   - Windows RDP client connections"
echo "   - Remote desktop access to Kali Linux"
echo "   - Secure authentication and session management"
echo ""
echo "⚠️  Security considerations:"
echo "   - This opens port 3389 for RDP connections"
echo "   - Use strong passwords and consider firewall rules"
echo "   - Consider SSH tunneling for additional security"
echo ""
read -p "Continue installation? (Y/n): " -r
if [[ "$REPLY" =~ ^[Nn]$ ]]; then
    echo "Exiting..."
    exit 1
fi

# Update package lists
echo ""
echo "📦 Updating package lists..."
sudo apt update

# Install XRDP and required packages
echo ""
echo "🔧 Installing XRDP server and dependencies..."
sudo apt install -y \
    xrdp \
    xfce4 \
    xfce4-goodies \
    firefox-esr \
    thunar \
    xfce4-terminal \
    pulseaudio \
    pavucontrol \
    tightvncserver \
    dbus-x11

echo "✅ XRDP and desktop components installed"

# Configure XRDP
echo ""
echo "⚙️  Configuring XRDP server..."

# Backup original xrdp config
sudo cp /etc/xrdp/xrdp.ini /etc/xrdp/xrdp.ini.backup.$(date +%Y%m%d_%H%M%S)

# Configure xrdp.ini for better performance and compatibility
sudo tee /etc/xrdp/xrdp.ini > /dev/null << 'EOF'
[Globals]
ini_version=1
fork=true
port=3389
tcp_nodelay=true
tcp_keepalive=true
security_layer=negotiate
crypt_level=high
certificate=
key_file=
ssl_protocols=TLSv1.2, TLSv1.3
tls_ciphers=HIGH
autorun=
allow_channels=true
allow_multimon=true
bitmap_cache=true
bitmap_compression=true
bulk_compression=true
hidelogwindow=true
max_bpp=32
new_cursors=true
use_fastpath=both
log_file=xrdp.log
log_level=INFO
enable_syslog=true
syslog_level=INFO

[Xorg]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=20

[Xvnc]
name=Xvnc
lib=libvnc.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=10
EOF

# Configure startwm.sh for Xfce
echo ""
echo "🖥️  Configuring desktop environment..."
sudo tee /etc/xrdp/startwm.sh > /dev/null << 'EOF'
#!/bin/sh
# xrdp X session start script (c) 2015, 2017, 2021 mirabilos
# published under The MirOS Licence

# Rely on /etc/pam.d/xrdp-sesman using pam_env to load both
# /etc/environment and /etc/default/locale to initialise the
# locale and the user environment properly.

if test -r /etc/profile; then
	. /etc/profile
fi

if test -r /etc/default/locale; then
	. /etc/default/locale
	test -z "${LANG+x}" || export LANG
	test -z "${LANGUAGE+x}" || export LANGUAGE
	test -z "${LC_ADDRESS+x}" || export LC_ADDRESS
	test -z "${LC_ALL+x}" || export LC_ALL
	test -z "${LC_COLLATE+x}" || export LC_COLLATE
	test -z "${LC_CTYPE+x}" || export LC_CTYPE
	test -z "${LC_IDENTIFICATION+x}" || export LC_IDENTIFICATION
	test -z "${LC_MEASUREMENT+x}" || export LC_MEASUREMENT
	test -z "${LC_MESSAGES+x}" || export LC_MESSAGES
	test -z "${LC_MONETARY+x}" || export LC_MONETARY
	test -z "${LC_NAME+x}" || export LC_NAME
	test -z "${LC_NUMERIC+x}" || export LC_NUMERIC
	test -z "${LC_PAPER+x}" || export LC_PAPER
	test -z "${LC_TELEPHONE+x}" || export LC_TELEPHONE
	test -z "${LC_TIME+x}" || export LC_TIME
fi

# Fix for Kali Linux - ensure proper session initialization
export XDG_SESSION_DESKTOP=xfce
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/share:/usr/local/share
export XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg

# Start Xfce4 session
startxfce4
EOF

sudo chmod +x /etc/xrdp/startwm.sh

# Configure user session for better RDP experience
echo ""
echo "👤 Configuring user session..."

# Create xsessionrc for current user
cat > ~/.xsessionrc << 'EOF'
export XDG_SESSION_DESKTOP=xfce
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/share:/usr/local/share
export XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg
EOF

# Create .xsession for current user
cat > ~/.xsession << 'EOF'
#!/bin/bash
export XDG_SESSION_DESKTOP=xfce
export XDG_DATA_DIRS=/usr/share/xfce4:/usr/share:/usr/local/share
export XDG_CONFIG_DIRS=/etc/xdg/xfce4:/etc/xdg
startxfce4
EOF

chmod +x ~/.xsession

# Add xrdp user to ssl-cert group for certificate access
echo ""
echo "🔐 Configuring permissions..."
sudo adduser xrdp ssl-cert

# Configure firewall (if ufw is active)
echo ""
echo "🔥 Configuring firewall..."
if systemctl is-active --quiet ufw; then
    echo "UFW firewall is active. Adding RDP rule..."
    sudo ufw allow 3389/tcp comment 'XRDP RDP Server'
    echo "✅ Firewall rule added for RDP (port 3389)"
elif command -v iptables &> /dev/null; then
    echo "💡 Note: Consider adding iptables rule for RDP access:"
    echo "   sudo iptables -A INPUT -p tcp --dport 3389 -j ACCEPT"
else
    echo "⚠️  No firewall detected. RDP port 3389 is open by default."
fi

# Configure audio redirection
echo ""
echo "🔊 Configuring audio redirection..."
# Install and configure PulseAudio modules for RDP
sudo apt install -y pulseaudio-module-xrdp

# Create PulseAudio configuration for RDP users
sudo tee /etc/pulse/xrdp.pa > /dev/null << 'EOF'
#!/usr/bin/pulseaudio -nF
# PulseAudio configuration for XRDP

# Load necessary modules for audio redirection
load-module module-native-protocol-unix auth-anonymous=1 socket=/tmp/pulse-socket
load-module module-xrdp-sink
load-module module-xrdp-source
EOF

# Start and enable XRDP service
echo ""
echo "🚀 Starting XRDP service..."
sudo systemctl enable xrdp
sudo systemctl restart xrdp
sudo systemctl enable xrdp-sesman
sudo systemctl restart xrdp-sesman

# Check service status
if systemctl is-active --quiet xrdp; then
    echo "✅ XRDP service is running"
else
    echo "❌ XRDP service failed to start"
    echo "Check logs: sudo journalctl -u xrdp"
fi

# Create connection scripts and shortcuts
echo ""
echo "📝 Creating connection utilities..."

# Create scripts directory
mkdir -p ~/rdp-server-utils
UTILS_DIR="$HOME/rdp-server-utils"

# XRDP status script
cat > "$UTILS_DIR/xrdp-status.sh" << 'EOF'
#!/bin/bash
# XRDP Server Status and Management

echo "========================================"
echo "       XRDP Server Status"
echo "========================================"
echo ""

# Check service status
echo "🔧 Service Status:"
echo -n "   XRDP: "
if systemctl is-active --quiet xrdp; then
    echo "✅ Running"
else
    echo "❌ Stopped"
fi

echo -n "   XRDP-SESMAN: "
if systemctl is-active --quiet xrdp-sesman; then
    echo "✅ Running"
else
    echo "❌ Stopped"
fi

# Check port
echo ""
echo "🌐 Network Status:"
if ss -tlnp | grep -q ":3389"; then
    echo "   ✅ Port 3389 is listening"
else
    echo "   ❌ Port 3389 is not listening"
fi

# Show IP addresses
echo ""
echo "📍 Connection Information:"
echo "   Local IP addresses:"
hostname -I | tr ' ' '\n' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | while read ip; do
    echo "      $ip:3389"
done

# Check for active sessions
echo ""
echo "👥 Active RDP Sessions:"
if command -v xrdp-sesrun &> /dev/null; then
    xrdp-sesrun -l 2>/dev/null || echo "   No active sessions"
else
    ps aux | grep -E "(Xorg|Xvnc).*:[0-9]+" | grep -v grep | wc -l | xargs echo "   Active X sessions:"
fi

echo ""
echo "📋 Quick Actions:"
echo "   Restart XRDP: sudo systemctl restart xrdp xrdp-sesman"
echo "   View logs: sudo journalctl -u xrdp -f"
echo "   Stop XRDP: sudo systemctl stop xrdp xrdp-sesman"
EOF

chmod +x "$UTILS_DIR/xrdp-status.sh"

# XRDP management script
cat > "$UTILS_DIR/manage-xrdp.sh" << 'EOF'
#!/bin/bash
# XRDP Server Management Script

show_menu() {
    echo "========================================"
    echo "       XRDP Server Management"
    echo "========================================"
    echo ""
    echo "1) Status - Show XRDP status"
    echo "2) Start - Start XRDP services"
    echo "3) Stop - Stop XRDP services"
    echo "4) Restart - Restart XRDP services"
    echo "5) Logs - View XRDP logs"
    echo "6) Sessions - Show active sessions"
    echo "7) Config - Edit configuration"
    echo "8) Firewall - Manage firewall rules"
    echo "9) Exit"
    echo ""
}

while true; do
    show_menu
    read -p "Select option (1-9): " choice
    echo ""
    
    case $choice in
        1)
            ~/rdp-server-utils/xrdp-status.sh
            ;;
        2)
            echo "🚀 Starting XRDP services..."
            sudo systemctl start xrdp xrdp-sesman
            echo "✅ Services started"
            ;;
        3)
            echo "🛑 Stopping XRDP services..."
            sudo systemctl stop xrdp xrdp-sesman
            echo "✅ Services stopped"
            ;;
        4)
            echo "🔄 Restarting XRDP services..."
            sudo systemctl restart xrdp xrdp-sesman
            echo "✅ Services restarted"
            ;;
        5)
            echo "📋 XRDP Logs (press Ctrl+C to exit):"
            sudo journalctl -u xrdp -f
            ;;
        6)
            echo "👥 Active Sessions:"
            ps aux | grep -E "(Xorg|Xvnc).*:[0-9]+" | grep -v grep
            who
            ;;
        7)
            echo "⚙️  Opening XRDP configuration..."
            sudo nano /etc/xrdp/xrdp.ini
            ;;
        8)
            echo "🔥 Firewall Management:"
            if command -v ufw &> /dev/null; then
                echo "Current UFW status:"
                sudo ufw status
                echo ""
                read -p "Allow RDP through firewall? (y/N): " -r
                if [[ "$REPLY" =~ ^[Yy]$ ]]; then
                    sudo ufw allow 3389/tcp
                    echo "✅ RDP allowed through firewall"
                fi
            else
                echo "UFW not available. Manual iptables rule:"
                echo "sudo iptables -A INPUT -p tcp --dport 3389 -j ACCEPT"
            fi
            ;;
        9)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *)
            echo "❌ Invalid option. Please try again."
            ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done
EOF

chmod +x "$UTILS_DIR/manage-xrdp.sh"

# Create desktop shortcut for XRDP management
DESKTOP_DIR="$HOME/Desktop"
if [[ ! -d "$DESKTOP_DIR" ]]; then
    mkdir -p "$DESKTOP_DIR"
fi

cat > "$DESKTOP_DIR/XRDP-Server-Manager.desktop" << EOF
[Desktop Entry]
Name=XRDP Server Manager
Comment=Manage Kali Linux RDP Server
Exec=gnome-terminal -- $HOME/rdp-server-utils/manage-xrdp.sh
Icon=krfb
Type=Application
Categories=Network;RemoteAccess;System;
Terminal=true
StartupNotify=true
EOF

chmod +x "$DESKTOP_DIR/XRDP-Server-Manager.desktop"

# Create command aliases
echo ""
echo "📝 Creating command aliases..."
BASHRC="$HOME/.bashrc"
if ! grep -q "xrdp-" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << EOF

# XRDP Server Management Aliases
alias xrdp-status='$HOME/rdp-server-utils/xrdp-status.sh'
alias xrdp-manage='$HOME/rdp-server-utils/manage-xrdp.sh'
alias xrdp-start='sudo systemctl start xrdp xrdp-sesman'
alias xrdp-stop='sudo systemctl stop xrdp xrdp-sesman'
alias xrdp-restart='sudo systemctl restart xrdp xrdp-sesman'
alias xrdp-logs='sudo journalctl -u xrdp -f'
EOF
    echo "✅ Command aliases added to ~/.bashrc"
fi

# Final status check and summary
echo ""
echo "🔍 Final status check..."
sleep 2

IP_ADDR=$(hostname -I | awk '{print $1}')
RDP_STATUS="❌ Stopped"
if systemctl is-active --quiet xrdp; then
    RDP_STATUS="✅ Running"
fi

echo ""
echo "========================================"
echo "✅ Kali Linux RDP Server Setup Complete!"
echo "========================================"
echo ""
echo "📋 Installation Summary:"
echo "   ✅ XRDP server installed and configured"
echo "   ✅ Xfce desktop environment ready for RDP"
echo "   ✅ Audio redirection configured"
echo "   ✅ User sessions properly configured"
echo "   ✅ Management utilities created"
echo ""
echo "🌐 Connection Information:"
echo "   Status: $RDP_STATUS"
echo "   IP Address: $IP_ADDR"
echo "   RDP Port: 3389"
echo "   Protocol: RDP (Remote Desktop Protocol)"
echo ""
echo "🖥️  From Windows, connect using:"
echo "   1. Open 'Remote Desktop Connection' (mstsc)"
echo "   2. Enter: $IP_ADDR"
echo "   3. Use your Kali Linux username/password"
echo "   4. Select 'Xorg' session type when prompted"
echo ""
echo "🔧 Management Tools:"
echo "   Desktop: 'XRDP Server Manager' shortcut"
echo "   Terminal: xrdp-status, xrdp-manage, xrdp-restart"
echo "   Config: /etc/xrdp/xrdp.ini"
echo "   Logs: sudo journalctl -u xrdp"
echo ""
echo "🔒 Security Recommendations:"
echo "   ✅ Use strong passwords"
echo "   ✅ Consider SSH tunneling: ssh -L 3389:localhost:3389 user@kali-ip"
echo "   ✅ Configure firewall rules appropriately"
echo "   ✅ Monitor connection logs regularly"
echo ""
echo "💡 Troubleshooting:"
echo "   - If connection fails, check: xrdp-status"
echo "   - For audio issues, restart PulseAudio in RDP session"
echo "   - For session issues, try different session types (Xorg/Xvnc)"
echo "   - Check firewall: sudo ufw status"
echo ""
echo "🚀 Ready to accept RDP connections!"
echo ""
echo "⚠️  Note: Restart terminal or run 'source ~/.bashrc' for aliases"