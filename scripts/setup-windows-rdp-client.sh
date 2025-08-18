#!/bin/bash
# Kali Linux Windows RDP Client Setup Script
# Installs and configures RDP clients for connecting to Windows machines

set -e

echo "========================================"
echo "  Kali Linux Windows RDP Client Setup"
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

echo "🖥️  This script will install and configure:"
echo "   - FreeRDP (rdesktop replacement)"
echo "   - Remmina (GUI RDP client)"
echo "   - XRDP tools"
echo "   - Connection scripts and shortcuts"
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

# Install RDP clients
echo ""
echo "🔧 Installing RDP clients..."
sudo apt install -y \
    freerdp2-x11 \
    remmina \
    remmina-plugin-rdp \
    remmina-plugin-vnc \
    remmina-plugin-nx \
    remmina-plugin-xdmcp \
    remmina-plugin-exec \
    vinagre \
    krdc \
    xfreerdp \
    rdesktop

echo "✅ RDP clients installed successfully"

# Create RDP connection scripts
echo ""
echo "📝 Creating RDP connection scripts..."

# Create scripts directory
mkdir -p ~/rdp-scripts
SCRIPTS_DIR="$HOME/rdp-scripts"

# FreeRDP connection script
cat > "$SCRIPTS_DIR/connect-windows-rdp.sh" << 'EOF'
#!/bin/bash
# Windows RDP Connection Script using FreeRDP

# Default values
DEFAULT_WIDTH=1920
DEFAULT_HEIGHT=1080
DEFAULT_USER=""
DEFAULT_DOMAIN=""

# Function to show usage
show_usage() {
    echo "Usage: $0 <IP_ADDRESS> [options]"
    echo ""
    echo "Options:"
    echo "  -u, --user USERNAME     Username for connection"
    echo "  -d, --domain DOMAIN     Domain name (optional)"
    echo "  -w, --width WIDTH       Screen width (default: 1920)"
    echo "  -h, --height HEIGHT     Screen height (default: 1080)"
    echo "  -f, --fullscreen        Use fullscreen mode"
    echo "  --admin                 Connect to admin session"
    echo "  --console               Connect to console session"
    echo "  --clipboard             Enable clipboard sharing"
    echo "  --sound                 Enable sound redirection"
    echo "  --drives                Enable drive redirection"
    echo "  --help                  Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 192.168.1.100 -u administrator"
    echo "  $0 10.0.0.5 -u john -d COMPANY --fullscreen --clipboard"
    echo "  $0 192.168.1.10 --admin --console"
}

# Parse arguments
IP_ADDRESS=""
USERNAME="$DEFAULT_USER"
DOMAIN="$DEFAULT_DOMAIN"
WIDTH="$DEFAULT_WIDTH"
HEIGHT="$DEFAULT_HEIGHT"
FULLSCREEN=false
ADMIN=false
CONSOLE=false
CLIPBOARD=false
SOUND=false
DRIVES=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--user)
            USERNAME="$2"
            shift 2
            ;;
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -w|--width)
            WIDTH="$2"
            shift 2
            ;;
        -h|--height)
            HEIGHT="$2"
            shift 2
            ;;
        -f|--fullscreen)
            FULLSCREEN=true
            shift
            ;;
        --admin)
            ADMIN=true
            shift
            ;;
        --console)
            CONSOLE=true
            shift
            ;;
        --clipboard)
            CLIPBOARD=true
            shift
            ;;
        --sound)
            SOUND=true
            shift
            ;;
        --drives)
            DRIVES=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
        *)
            if [[ -z "$IP_ADDRESS" ]]; then
                IP_ADDRESS="$1"
            else
                echo "Multiple IP addresses specified"
                show_usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate IP address
if [[ -z "$IP_ADDRESS" ]]; then
    echo "❌ Error: IP address is required"
    show_usage
    exit 1
fi

# Build FreeRDP command
FREERDP_CMD="xfreerdp"

# Basic connection parameters
FREERDP_CMD="$FREERDP_CMD /v:$IP_ADDRESS"

# User authentication
if [[ -n "$USERNAME" ]]; then
    if [[ -n "$DOMAIN" ]]; then
        FREERDP_CMD="$FREERDP_CMD /u:${DOMAIN}\\${USERNAME}"
    else
        FREERDP_CMD="$FREERDP_CMD /u:$USERNAME"
    fi
fi

# Screen resolution
if [[ "$FULLSCREEN" == true ]]; then
    FREERDP_CMD="$FREERDP_CMD /f"
else
    FREERDP_CMD="$FREERDP_CMD /size:${WIDTH}x${HEIGHT}"
fi

# Session options
if [[ "$ADMIN" == true ]]; then
    FREERDP_CMD="$FREERDP_CMD /admin"
fi

if [[ "$CONSOLE" == true ]]; then
    FREERDP_CMD="$FREERDP_CMD /console"
fi

# Feature options
if [[ "$CLIPBOARD" == true ]]; then
    FREERDP_CMD="$FREERDP_CMD +clipboard"
fi

if [[ "$SOUND" == true ]]; then
    FREERDP_CMD="$FREERDP_CMD /sound:sys:alsa"
fi

if [[ "$DRIVES" == true ]]; then
    FREERDP_CMD="$FREERDP_CMD /drive:home,$HOME"
fi

# Security and compatibility options
FREERDP_CMD="$FREERDP_CMD /cert-ignore"
FREERDP_CMD="$FREERDP_CMD /compression"
FREERDP_CMD="$FREERDP_CMD +themes"
FREERDP_CMD="$FREERDP_CMD +wallpaper"

echo "🔗 Connecting to Windows machine: $IP_ADDRESS"
if [[ -n "$USERNAME" ]]; then
    echo "👤 User: $USERNAME"
fi
if [[ -n "$DOMAIN" ]]; then
    echo "🏢 Domain: $DOMAIN"
fi
echo "📺 Resolution: ${WIDTH}x${HEIGHT}"
if [[ "$FULLSCREEN" == true ]]; then
    echo "🖥️  Mode: Fullscreen"
fi
echo ""
echo "🚀 Executing: $FREERDP_CMD"
echo ""

# Execute connection
exec $FREERDP_CMD
EOF

chmod +x "$SCRIPTS_DIR/connect-windows-rdp.sh"

# Quick connect script for common scenarios
cat > "$SCRIPTS_DIR/quick-rdp.sh" << 'EOF'
#!/bin/bash
# Quick RDP connection script with common presets

echo "========================================"
echo "     Quick Windows RDP Connection"
echo "========================================"
echo ""

# Get target IP
read -p "🖥️  Enter Windows machine IP address: " IP_ADDRESS
if [[ -z "$IP_ADDRESS" ]]; then
    echo "❌ IP address is required"
    exit 1
fi

# Get username
read -p "👤 Enter username (or press Enter for current user): " USERNAME
if [[ -z "$USERNAME" ]]; then
    USERNAME="$USER"
fi

# Get domain (optional)
read -p "🏢 Enter domain (optional, press Enter to skip): " DOMAIN

# Connection options menu
echo ""
echo "🔧 Connection Options:"
echo "1) Standard connection (1920x1080)"
echo "2) Fullscreen connection"
echo "3) Admin session (fullscreen)"
echo "4) Console session with admin rights"
echo "5) Full-featured connection (clipboard, sound, drives)"
echo ""
read -p "Select option (1-5): " OPTION

case $OPTION in
    1)
        ARGS="-u $USERNAME"
        ;;
    2)
        ARGS="-u $USERNAME --fullscreen"
        ;;
    3)
        ARGS="-u $USERNAME --fullscreen --admin"
        ;;
    4)
        ARGS="-u $USERNAME --fullscreen --admin --console"
        ;;
    5)
        ARGS="-u $USERNAME --fullscreen --clipboard --sound --drives"
        ;;
    *)
        echo "Invalid option, using standard connection"
        ARGS="-u $USERNAME"
        ;;
esac

# Add domain if specified
if [[ -n "$DOMAIN" ]]; then
    ARGS="$ARGS -d $DOMAIN"
fi

# Execute connection
echo ""
echo "🚀 Connecting..."
exec "$HOME/rdp-scripts/connect-windows-rdp.sh" $IP_ADDRESS $ARGS
EOF

chmod +x "$SCRIPTS_DIR/quick-rdp.sh"

# RDP scanner script
cat > "$SCRIPTS_DIR/scan-rdp.sh" << 'EOF'
#!/bin/bash
# RDP Service Scanner - Find Windows machines with RDP enabled

echo "========================================"
echo "        RDP Service Scanner"
echo "========================================"
echo ""

# Check if nmap is installed
if ! command -v nmap &> /dev/null; then
    echo "📦 Installing nmap..."
    sudo apt update && sudo apt install -y nmap
fi

# Get network range
read -p "🌐 Enter network range to scan (e.g., 192.168.1.0/24): " NETWORK
if [[ -z "$NETWORK" ]]; then
    echo "❌ Network range is required"
    exit 1
fi

echo ""
echo "🔍 Scanning for RDP services on $NETWORK..."
echo "   This may take a few minutes..."
echo ""

# Scan for RDP (port 3389)
nmap -sS -p 3389 --open "$NETWORK" | grep -E "(Nmap scan report|3389)"

echo ""
echo "✅ RDP scan complete!"
echo ""
echo "💡 To connect to a discovered machine:"
echo "   ~/rdp-scripts/quick-rdp.sh"
EOF

chmod +x "$SCRIPTS_DIR/scan-rdp.sh"

# Create desktop shortcuts
echo ""
echo "🔗 Creating desktop shortcuts..."

DESKTOP_DIR="$HOME/Desktop"
if [[ ! -d "$DESKTOP_DIR" ]]; then
    mkdir -p "$DESKTOP_DIR"
fi

# Remmina shortcut
cat > "$DESKTOP_DIR/Remmina-RDP-Client.desktop" << EOF
[Desktop Entry]
Name=Remmina RDP Client
Comment=Remote Desktop Client for Windows
Exec=remmina
Icon=remmina
Type=Application
Categories=Network;RemoteAccess;
Terminal=false
StartupNotify=true
EOF

chmod +x "$DESKTOP_DIR/Remmina-RDP-Client.desktop"

# Quick RDP shortcut
cat > "$DESKTOP_DIR/Quick-RDP-Connect.desktop" << EOF
[Desktop Entry]
Name=Quick RDP Connect
Comment=Quick Windows RDP Connection
Exec=gnome-terminal -- $HOME/rdp-scripts/quick-rdp.sh
Icon=krdc
Type=Application
Categories=Network;RemoteAccess;
Terminal=true
StartupNotify=true
EOF

chmod +x "$DESKTOP_DIR/Quick-RDP-Connect.desktop"

# RDP Scanner shortcut
cat > "$DESKTOP_DIR/RDP-Scanner.desktop" << EOF
[Desktop Entry]
Name=RDP Scanner
Comment=Scan network for RDP services
Exec=gnome-terminal -- $HOME/rdp-scripts/scan-rdp.sh
Icon=nmap
Type=Application
Categories=Network;Security;
Terminal=true
StartupNotify=true
EOF

chmod +x "$DESKTOP_DIR/RDP-Scanner.desktop"

# Create configuration file
echo ""
echo "⚙️  Creating configuration file..."
cat > "$SCRIPTS_DIR/rdp-config.conf" << EOF
# RDP Connection Configuration
# Edit these values to set defaults

# Default screen resolution
DEFAULT_WIDTH=1920
DEFAULT_HEIGHT=1080

# Default authentication (leave empty to prompt)
DEFAULT_USERNAME=""
DEFAULT_DOMAIN=""

# Default connection options
ENABLE_CLIPBOARD=true
ENABLE_SOUND=true
ENABLE_DRIVES=false
CERT_IGNORE=true
COMPRESSION=true
THEMES=true
WALLPAPER=true

# Security settings
VERIFY_CERTIFICATES=false
IGNORE_CERTIFICATE_ERRORS=true
EOF

# Create alias for easy access
echo ""
echo "📝 Creating command aliases..."
BASHRC="$HOME/.bashrc"
if ! grep -q "rdp-scripts" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << EOF

# RDP Connection Aliases
alias rdp='$HOME/rdp-scripts/quick-rdp.sh'
alias rdp-connect='$HOME/rdp-scripts/connect-windows-rdp.sh'
alias rdp-scan='$HOME/rdp-scripts/scan-rdp.sh'
alias rdp-gui='remmina'
EOF
    echo "✅ Command aliases added to ~/.bashrc"
fi

# Summary
echo ""
echo "========================================"
echo "✅ Windows RDP Client Setup Complete!"
echo "========================================"
echo ""
echo "📋 Installed applications:"
echo "   ✅ FreeRDP (xfreerdp) - Command-line RDP client"
echo "   ✅ Remmina - GUI RDP client"
echo "   ✅ Additional RDP tools and plugins"
echo ""
echo "📝 Created scripts in ~/rdp-scripts/:"
echo "   ✅ connect-windows-rdp.sh - Advanced RDP connection"
echo "   ✅ quick-rdp.sh - Interactive connection wizard"
echo "   ✅ scan-rdp.sh - Network RDP scanner"
echo ""
echo "🔗 Desktop shortcuts created:"
echo "   ✅ Remmina RDP Client"
echo "   ✅ Quick RDP Connect"
echo "   ✅ RDP Scanner"
echo ""
echo "💻 Command aliases (restart terminal or run 'source ~/.bashrc'):"
echo "   rdp                 - Quick connect wizard"
echo "   rdp-connect         - Advanced connection script"
echo "   rdp-scan           - Network scanner"
echo "   rdp-gui            - Launch Remmina GUI"
echo ""
echo "🚀 Usage examples:"
echo "   rdp                                    # Interactive wizard"
echo "   rdp-connect 192.168.1.100 -u admin   # Direct connection"
echo "   rdp-scan                              # Find RDP services"
echo "   remmina                               # GUI client"
echo ""
echo "⚙️  Configuration file: ~/rdp-scripts/rdp-config.conf"
echo ""
echo "💡 Tips:"
echo "   - Use Remmina GUI for saving connection profiles"
echo "   - Run 'rdp-scan' to discover Windows machines on network"
echo "   - Enable clipboard/sound/drives in connection options"
echo "   - For high-security environments, consider SSH tunneling"