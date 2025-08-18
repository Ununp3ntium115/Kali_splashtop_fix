#!/bin/bash
# Master Setup Script for Kali Linux Splashtop and RDP Configuration
# Runs all setup scripts in proper sequence with user choices

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOG_FILE="$HOME/kali-setup-$(date +%Y%m%d_%H%M%S).log"

echo "========================================"
echo "  Kali Linux Master Setup Script"
echo "========================================"
echo ""
echo "🚀 This script will help you set up:"
echo "   1. Splashtop Streamer for Kali Linux"
echo "   2. Root access enablement (optional)"
echo "   3. Windows RDP client tools (optional)"
echo "   4. Kali RDP server setup (optional)"
echo ""
echo "📝 Setup log will be saved to: $LOG_FILE"
echo ""

# Check if running on Kali Linux
if ! grep -q "kali" /etc/os-release 2>/dev/null; then
    echo "⚠️  Warning: This script is designed for Kali Linux."
    read -p "Continue anyway? (y/N): " -r
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
        echo "Exiting..."
        exit 1
    fi
fi

# Log function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to run script with logging
run_script() {
    local script_path="$1"
    local script_name="$(basename "$script_path")"
    
    log_message "Starting $script_name"
    echo ""
    echo "🔧 Running: $script_name"
    echo "----------------------------------------"
    
    if [[ -x "$script_path" ]]; then
        "$script_path" 2>&1 | tee -a "$LOG_FILE"
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_message "✅ $script_name completed successfully"
        else
            log_message "❌ $script_name failed with exit code $exit_code"
            echo ""
            echo "❌ Error: $script_name failed!"
            read -p "Continue with next script? (Y/n): " -r
            if [[ "$REPLY" =~ ^[Nn]$ ]]; then
                echo "Setup interrupted by user."
                exit 1
            fi
        fi
    else
        log_message "❌ $script_name not found or not executable"
        echo "❌ Error: Script not found: $script_path"
        return 1
    fi
    
    echo ""
    echo "----------------------------------------"
    echo ""
}

# Interactive menu
show_setup_menu() {
    echo "📋 Setup Options:"
    echo ""
    echo "1) Complete Setup (All components)"
    echo "2) Splashtop Streamer only"
    echo "3) Custom selection"
    echo "4) Exit"
    echo ""
}

# Get user choice
while true; do
    show_setup_menu
    read -p "Select option (1-4): " choice
    echo ""
    
    case $choice in
        1)
            # Complete setup
            echo "🚀 Starting complete setup..."
            INSTALL_ROOT=true
            INSTALL_RDP_CLIENT=true
            INSTALL_RDP_SERVER=true
            INSTALL_SPLASHTOP=true
            break
            ;;
        2)
            # Splashtop only
            echo "📦 Splashtop Streamer setup only"
            INSTALL_ROOT=false
            INSTALL_RDP_CLIENT=false
            INSTALL_RDP_SERVER=false
            INSTALL_SPLASHTOP=true
            break
            ;;
        3)
            # Custom selection
            echo "🔧 Custom component selection:"
            echo ""
            
            read -p "Install Splashtop Streamer? (Y/n): " -r
            INSTALL_SPLASHTOP=$([ "$REPLY" != "${REPLY#[Nn]}" ] && echo false || echo true)
            
            read -p "Enable root login? (y/N): " -r
            INSTALL_ROOT=$([ "$REPLY" == "${REPLY#[Yy]}" ] && echo false || echo true)
            
            read -p "Setup Windows RDP client tools? (y/N): " -r
            INSTALL_RDP_CLIENT=$([ "$REPLY" == "${REPLY#[Yy]}" ] && echo false || echo true)
            
            read -p "Setup Kali RDP server? (y/N): " -r
            INSTALL_RDP_SERVER=$([ "$REPLY" == "${REPLY#[Yy]}" ] && echo false || echo true)
            
            break
            ;;
        4)
            echo "👋 Exiting setup..."
            exit 0
            ;;
        *)
            echo "❌ Invalid option. Please try again."
            echo ""
            ;;
    esac
done

# Display selected components
echo "📋 Selected components:"
[[ "$INSTALL_SPLASHTOP" == true ]] && echo "   ✅ Splashtop Streamer"
[[ "$INSTALL_ROOT" == true ]] && echo "   ✅ Root login enablement"
[[ "$INSTALL_RDP_CLIENT" == true ]] && echo "   ✅ Windows RDP client tools"
[[ "$INSTALL_RDP_SERVER" == true ]] && echo "   ✅ Kali RDP server"
echo ""

read -p "Proceed with installation? (Y/n): " -r
if [[ "$REPLY" =~ ^[Nn]$ ]]; then
    echo "Setup cancelled by user."
    exit 0
fi

# Start setup process
log_message "Starting Kali Linux master setup"
echo ""
echo "🚀 Starting setup process..."
echo "========================================"

# Step 1: Install Splashtop Streamer
if [[ "$INSTALL_SPLASHTOP" == true ]]; then
    echo ""
    echo "📦 Step 1: Installing Splashtop Streamer..."
    
    # Check if deb package exists
    DEB_KALI="$SCRIPT_DIR/../Splashtop_Streamer_Kali_amd64.deb"
    DEB_UBUNTU="$SCRIPT_DIR/../Splashtop_Streamer_Ubuntu_amd64.deb"
    
    if [[ -f "$DEB_KALI" ]]; then
        log_message "Installing Kali Linux optimized Splashtop package"
        echo "📦 Installing: Splashtop_Streamer_Kali_amd64.deb"
        sudo dpkg -i "$DEB_KALI" 2>&1 | tee -a "$LOG_FILE"
        sudo apt-get install -f 2>&1 | tee -a "$LOG_FILE"
        log_message "✅ Splashtop Streamer installed successfully"
    elif [[ -f "$DEB_UBUNTU" ]]; then
        log_message "Installing Ubuntu Splashtop package (fallback)"
        echo "📦 Installing: Splashtop_Streamer_Ubuntu_amd64.deb"
        sudo apt install "$DEB_UBUNTU" 2>&1 | tee -a "$LOG_FILE"
        log_message "✅ Splashtop Streamer installed successfully"
    else
        log_message "❌ Splashtop deb package not found"
        echo "❌ Error: Splashtop deb package not found in parent directory"
        echo "   Expected: $DEB_KALI or $DEB_UBUNTU"
        exit 1
    fi
    
    # Verify installation
    if systemctl is-active --quiet SRStreamer.service; then
        log_message "✅ Splashtop service is running"
        echo "✅ Splashtop Streamer service is active"
    else
        log_message "⚠️ Splashtop service not active, attempting to start"
        sudo systemctl start SRStreamer.service || true
    fi
fi

# Step 2: Enable root login
if [[ "$INSTALL_ROOT" == true ]]; then
    echo ""
    echo "🔐 Step 2: Enabling root login..."
    run_script "$SCRIPT_DIR/enable-root-login.sh"
fi

# Step 3: Setup Windows RDP client
if [[ "$INSTALL_RDP_CLIENT" == true ]]; then
    echo ""
    echo "🖥️  Step 3: Setting up Windows RDP client tools..."
    run_script "$SCRIPT_DIR/setup-windows-rdp-client.sh"
fi

# Step 4: Setup Kali RDP server
if [[ "$INSTALL_RDP_SERVER" == true ]]; then
    echo ""
    echo "🌐 Step 4: Setting up Kali RDP server..."
    run_script "$SCRIPT_DIR/setup-kali-rdp-server.sh"
fi

# Final summary
echo ""
echo "========================================"
echo "✅ Master Setup Complete!"
echo "========================================"
echo ""

log_message "Setup completed successfully"

# Display summary
echo "📋 Installation Summary:"
if [[ "$INSTALL_SPLASHTOP" == true ]]; then
    echo "   ✅ Splashtop Streamer - $(systemctl is-active SRStreamer.service 2>/dev/null || echo 'Not running')"
fi
if [[ "$INSTALL_ROOT" == true ]]; then
    echo "   ✅ Root login enabled for GUI and SSH"
fi
if [[ "$INSTALL_RDP_CLIENT" == true ]]; then
    echo "   ✅ Windows RDP client tools installed"
fi
if [[ "$INSTALL_RDP_SERVER" == true ]]; then
    echo "   ✅ Kali RDP server configured"
fi

echo ""
echo "🌐 Network Information:"
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "   IP Address: $IP_ADDR"

if [[ "$INSTALL_RDP_SERVER" == true ]] && systemctl is-active --quiet xrdp; then
    echo "   RDP Server: ✅ Running on port 3389"
    echo "   Windows Connection: mstsc -> $IP_ADDR"
fi

if [[ "$INSTALL_SPLASHTOP" == true ]]; then
    echo "   Splashtop: Access via Splashtop client applications"
fi

echo ""
echo "📝 Setup log saved to: $LOG_FILE"
echo ""
echo "🔄 Recommended actions:"
echo "   - Reboot system to ensure all changes take effect"
echo "   - Test connections from remote machines"
echo "   - Review security settings and firewall rules"
echo ""
echo "💡 Quick commands (after terminal restart):"
if [[ "$INSTALL_ROOT" == true ]]; then
    echo "   - SSH root access: ssh root@$IP_ADDR"
fi
if [[ "$INSTALL_RDP_CLIENT" == true ]]; then
    echo "   - RDP to Windows: rdp"
fi
if [[ "$INSTALL_RDP_SERVER" == true ]]; then
    echo "   - Manage RDP server: xrdp-manage"
fi
if [[ "$INSTALL_SPLASHTOP" == true ]]; then
    echo "   - Splashtop config: splashtop-streamer config"
fi

echo ""
echo "🎉 Your Kali Linux system is ready for remote access!"
echo ""

# Offer to reboot
read -p "Reboot system now to apply all changes? (y/N): " -r
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
    log_message "System reboot initiated by user"
    echo "🔄 Rebooting system..."
    sudo reboot
else
    echo "⚠️  Remember to reboot later for all changes to take effect"
fi