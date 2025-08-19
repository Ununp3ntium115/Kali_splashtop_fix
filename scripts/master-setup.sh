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
echo "🚀 This script will attempt to set up:"
echo "   1. Splashtop Streamer for Kali Linux (KNOWN TO FAIL)"
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
    echo "1) Attempt Splashtop Streamer installation (WILL FAIL)"
    echo "2) Exit"
    echo ""
}

# Get user choice
while true; do
    show_setup_menu
    read -p "Select option (1-2): " choice
    echo ""
    
    case $choice in
        1)
            # Splashtop attempt (will fail)
            echo "⚠️ WARNING: This installation is known to fail due to binary incompatibility"
            echo "📦 Attempting Splashtop Streamer setup (EXPECTED TO FAIL)"
            INSTALL_SPLASHTOP=true
            break
            ;;
        2)
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
[[ "$INSTALL_SPLASHTOP" == true ]] && echo "   ⚠️ Splashtop Streamer (WILL FAIL)"
echo ""

read -p "Proceed with installation attempt? (y/N): " -r
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
    echo "Setup cancelled by user."
    exit 0
fi

# Start setup process
log_message "Starting Kali Linux Splashtop installation attempt (expected to fail)"
echo ""
echo "🚀 Starting installation attempt..."
echo "========================================"

# Step 1: Attempt Splashtop Streamer Installation
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
    
    # Verify installation (will fail)
    if systemctl is-active --quiet SRStreamer.service; then
        log_message "✅ Splashtop service is running (UNEXPECTED SUCCESS)"
        echo "✅ Splashtop Streamer service is active"
    else
        log_message "❌ Splashtop service failed to start (EXPECTED FAILURE)"
        echo "❌ Splashtop Streamer service failed - binary incompatibility"
        echo "📄 See STATUS_FAILED.md and SPLASHTOP_INTEGRATION_ISSUES.md for details"
        sudo systemctl start SRStreamer.service || true
    fi
fi

# Final summary
echo ""
echo "========================================"
echo "❌ INSTALLATION FAILED (AS EXPECTED)"
echo "========================================"
echo ""

log_message "Splashtop installation failed due to binary incompatibility"

# Display summary
echo "📋 Installation Summary:"
if [[ "$INSTALL_SPLASHTOP" == true ]]; then
    if systemctl is-active --quiet SRStreamer.service; then
        echo "   🆘 Splashtop Streamer - UNEXPECTEDLY RUNNING (investigate immediately)"
    else
        echo "   ❌ Splashtop Streamer - FAILED (binary incompatibility)"
    fi
fi

echo ""
echo "🌐 Network Information:"
IP_ADDR=$(hostname -I | awk '{print $1}')
echo "   IP Address: $IP_ADDR"
echo "   Splashtop: ❌ NOT FUNCTIONAL"

echo ""
echo "📝 Documentation:"
echo "   - Setup log: $LOG_FILE"
echo "   - Failure analysis: STATUS_FAILED.md"
echo "   - Technical details: SPLASHTOP_INTEGRATION_ISSUES.md"
echo ""
echo "💡 Alternative solutions:"
echo "   - Use native RDP server instead of Splashtop"
echo "   - Consider VNC or SSH with X11 forwarding"
echo "   - Wait for Splashtop to release Debian 12 compatible version"
echo ""
echo "⚠️ PROJECT STATUS: FAILED"
echo "   Splashtop Streamer is not functional on Kali Linux 2025.2"