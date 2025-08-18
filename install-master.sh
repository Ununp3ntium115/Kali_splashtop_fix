#!/bin/bash
# Master Installation Script for Splashtop Streamer on Kali Linux 2025.2
# Handles complete installation, configuration, and setup

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOGFILE="/tmp/splashtop-master-install-$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "$1" | tee -a "$LOGFILE"
}

log_section() {
    echo "" | tee -a "$LOGFILE"
    echo "========================================" | tee -a "$LOGFILE"
    echo "$1" | tee -a "$LOGFILE"
    echo "========================================" | tee -a "$LOGFILE"
    echo "" | tee -a "$LOGFILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log "${RED}❌ This script must be run as root (use sudo)${NC}"
    exit 1
fi

# Verify we're on Kali Linux
if ! grep -q "Kali" /etc/os-release 2>/dev/null; then
    log "${YELLOW}⚠️  Warning: This script is designed for Kali Linux${NC}"
    log "   Current system: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

log_section "SPLASHTOP STREAMER MASTER INSTALLER"
log "${BLUE}🚀 Starting comprehensive Splashtop installation for Kali Linux${NC}"
log "📝 Installation log: $LOGFILE"
log "⏰ Started: $(date)"
log ""

# Step 1: System preparation
log_section "STEP 1: SYSTEM PREPARATION"
log "${BLUE}🔄 Updating package lists...${NC}"
if apt update >> "$LOGFILE" 2>&1; then
    log "${GREEN}✅ Package lists updated${NC}"
else
    log "${RED}❌ Failed to update package lists${NC}"
    exit 1
fi

# Step 2: Install core Splashtop package
log_section "STEP 2: SPLASHTOP PACKAGE INSTALLATION"

if [[ -f "$SCRIPT_DIR/Splashtop_Streamer_Kali_amd64.deb" ]]; then
    log "${BLUE}📦 Installing Splashtop Streamer package...${NC}"
    
    # Try standard installation first
    if dpkg -i "$SCRIPT_DIR/Splashtop_Streamer_Kali_amd64.deb" >> "$LOGFILE" 2>&1; then
        log "${GREEN}✅ Package installed successfully${NC}"
    else
        log "${YELLOW}⚠️  Standard installation failed, trying fallback method...${NC}"
        
        # Use fallback installer if available
        if [[ -x "$SCRIPT_DIR/install-fallback.sh" ]]; then
            if "$SCRIPT_DIR/install-fallback.sh" >> "$LOGFILE" 2>&1; then
                log "${GREEN}✅ Fallback installation successful${NC}"
            else
                log "${RED}❌ Both standard and fallback installation failed${NC}"
                log "Check log file: $LOGFILE"
                exit 1
            fi
        else
            log "${RED}❌ Fallback installer not found${NC}"
            exit 1
        fi
    fi
else
    log "${RED}❌ Splashtop package not found: Splashtop_Streamer_Kali_amd64.deb${NC}"
    exit 1
fi

# Step 3: Fix dependencies
log_section "STEP 3: DEPENDENCY RESOLUTION"
log "${BLUE}🔧 Fixing dependencies...${NC}"

if [[ -x "$SCRIPT_DIR/fix-dependencies.sh" ]]; then
    if "$SCRIPT_DIR/fix-dependencies.sh" >> "$LOGFILE" 2>&1; then
        log "${GREEN}✅ Dependencies resolved${NC}"
    else
        log "${YELLOW}⚠️  Some dependency issues may remain${NC}"
    fi
else
    log "${BLUE}ℹ️  Running apt-get install -f for dependency resolution${NC}"
    apt-get install -f -y >> "$LOGFILE" 2>&1 || true
fi

# Step 4: Fix library paths and permissions
log_section "STEP 4: BINARY AND LIBRARY CONFIGURATION"
log "${BLUE}🔧 Fixing library paths and binary permissions...${NC}"

if [[ -x "$SCRIPT_DIR/fix-library-path.sh" ]]; then
    if "$SCRIPT_DIR/fix-library-path.sh" >> "$LOGFILE" 2>&1; then
        log "${GREEN}✅ Library paths and permissions fixed${NC}"
    else
        log "${RED}❌ Failed to fix library configuration${NC}"
        exit 1
    fi
else
    # Manual fix as fallback
    log "${BLUE}ℹ️  Applying manual library fixes...${NC}"
    
    # Make binaries executable
    chmod +x /opt/splashtop-streamer/SRFeature 2>/dev/null || true
    chmod +x /opt/splashtop-streamer/SRStreamer 2>/dev/null || true
    chmod +x /opt/splashtop-streamer/SRAgent 2>/dev/null || true
    chmod +x /usr/bin/splashtop-streamer 2>/dev/null || true
    
    # Setup library path
    echo "/opt/splashtop-streamer" > /etc/ld.so.conf.d/splashtop.conf
    ldconfig
    
    log "${GREEN}✅ Manual fixes applied${NC}"
fi

# Step 5: Firewall configuration
log_section "STEP 5: FIREWALL CONFIGURATION"
log "${BLUE}🔥 Configuring UFW firewall rules...${NC}"

if command -v ufw >/dev/null 2>&1; then
    # Allow Splashtop ports
    ufw allow 443/tcp >> "$LOGFILE" 2>&1 || true
    ufw allow 6783/tcp >> "$LOGFILE" 2>&1 || true
    ufw allow out 443/tcp >> "$LOGFILE" 2>&1 || true
    log "${GREEN}✅ Firewall rules configured${NC}"
else
    log "${YELLOW}⚠️  UFW not available, skipping firewall configuration${NC}"
fi

# Step 6: Service management
log_section "STEP 6: SERVICE CONFIGURATION"
log "${BLUE}🔄 Configuring and starting Splashtop service...${NC}"

# Reload systemd and enable service
systemctl daemon-reload >> "$LOGFILE" 2>&1
systemctl enable SRStreamer.service >> "$LOGFILE" 2>&1

# Start the service
if systemctl start SRStreamer.service >> "$LOGFILE" 2>&1; then
    log "${GREEN}✅ Service started successfully${NC}"
else
    log "${YELLOW}⚠️  Service start failed, checking status...${NC}"
    
    # Wait a moment and check status
    sleep 3
    if systemctl is-active --quiet SRStreamer.service; then
        log "${GREEN}✅ Service is now running${NC}"
    else
        log "${RED}❌ Service failed to start${NC}"
        log "Service status:" | tee -a "$LOGFILE"
        systemctl status SRStreamer.service --no-pager | tee -a "$LOGFILE"
        log "${BLUE}ℹ️  Check troubleshooting tools for detailed analysis${NC}"
    fi
fi

# Step 7: Optional enhancements (interactive)
log_section "STEP 7: OPTIONAL ENHANCEMENTS"
log "${BLUE}🚀 Optional enhancements available:${NC}"
log ""
log "Would you like to configure additional features?"
log "1. Enable root GUI login"
log "2. Setup Windows RDP client"
log "3. Setup Kali RDP server"
log "4. Skip optional features"
log ""
read -p "Select option (1-4): " -n 1 -r enhancement_choice
echo

case $enhancement_choice in
    1)
        log "${BLUE}🔐 Configuring root GUI login...${NC}"
        if [[ -x "$SCRIPT_DIR/scripts/enable-root-login.sh" ]]; then
            "$SCRIPT_DIR/scripts/enable-root-login.sh" | tee -a "$LOGFILE"
        else
            log "${YELLOW}⚠️  Root login script not found${NC}"
        fi
        ;;
    2)
        log "${BLUE}🖥️  Setting up Windows RDP client...${NC}"
        if [[ -x "$SCRIPT_DIR/scripts/setup-windows-rdp-client.sh" ]]; then
            "$SCRIPT_DIR/scripts/setup-windows-rdp-client.sh" | tee -a "$LOGFILE"
        else
            log "${YELLOW}⚠️  RDP client setup script not found${NC}"
        fi
        ;;
    3)
        log "${BLUE}🌐 Setting up Kali RDP server...${NC}"
        if [[ -x "$SCRIPT_DIR/scripts/setup-kali-rdp-server.sh" ]]; then
            "$SCRIPT_DIR/scripts/setup-kali-rdp-server.sh" | tee -a "$LOGFILE"
        else
            log "${YELLOW}⚠️  RDP server setup script not found${NC}"
        fi
        ;;
    4)
        log "${BLUE}ℹ️  Skipping optional features${NC}"
        ;;
    *)
        log "${YELLOW}⚠️  Invalid choice, skipping optional features${NC}"
        ;;
esac

# Step 8: Installation verification
log_section "STEP 8: INSTALLATION VERIFICATION"
log "${BLUE}🔍 Verifying installation...${NC}"

# Check package installation
if dpkg -l | grep -q splashtop-streamer; then
    log "${GREEN}✅ Package installed${NC}"
else
    log "${RED}❌ Package not found${NC}"
fi

# Check binary permissions
if [[ -x "/opt/splashtop-streamer/SRFeature" ]]; then
    log "${GREEN}✅ Main binary executable${NC}"
else
    log "${RED}❌ Main binary not executable${NC}"
fi

# Check service status
if systemctl is-active --quiet SRStreamer.service; then
    log "${GREEN}✅ Service is running${NC}"
    SERVICE_STATUS="running"
else
    log "${RED}❌ Service not running${NC}"
    SERVICE_STATUS="failed"
fi

# Check library dependencies
missing_libs=$(ldd /opt/splashtop-streamer/SRFeature 2>&1 | grep "not found" | wc -l)
if [[ $missing_libs -eq 0 ]]; then
    log "${GREEN}✅ All libraries found${NC}"
else
    log "${YELLOW}⚠️  $missing_libs missing libraries detected${NC}"
fi

# Final status report
log_section "INSTALLATION COMPLETE"
log "${GREEN}🎉 Splashtop Streamer Master Installation Complete!${NC}"
log ""
log "${BLUE}📊 Installation Summary:${NC}"
log "   • Package: $(dpkg -l | grep splashtop-streamer | awk '{print $3}' || echo 'Not found')"
log "   • Service: $SERVICE_STATUS"
log "   • Binary: $(test -x /opt/splashtop-streamer/SRFeature && echo 'Executable' || echo 'Not executable')"
log "   • Libraries: $(test $missing_libs -eq 0 && echo 'All found' || echo "$missing_libs missing")"
log "   • Firewall: $(command -v ufw >/dev/null && echo 'Configured' || echo 'Not configured')"
log ""
log "${BLUE}📝 Log file: $LOGFILE${NC}"
log "${BLUE}⏰ Completed: $(date)${NC}"
log ""

if [[ "$SERVICE_STATUS" == "running" && $missing_libs -eq 0 ]]; then
    log "${GREEN}🚀 SUCCESS: Splashtop Streamer is ready for use!${NC}"
    log ""
    log "${BLUE}🔗 Next Steps:${NC}"
    log "   1. Configure Splashtop account and deployment"
    log "   2. Test remote connection with Splashtop client"
    log "   3. Monitor service: systemctl status SRStreamer.service"
    log ""
    log "${BLUE}📱 Usage:${NC}"
    log "   • Deploy: splashtop-streamer deploy [DEPLOYMENT_CODE]"
    log "   • Config: splashtop-streamer config"
    log "   • Help: splashtop-streamer help"
else
    log "${YELLOW}⚠️  PARTIAL SUCCESS: Some issues detected${NC}"
    log ""
    log "${BLUE}🛠️  Troubleshooting:${NC}"
    if [[ -x "$SCRIPT_DIR/troubleshooting/master-troubleshoot.sh" ]]; then
        log "   • Run diagnostics: ./troubleshooting/master-troubleshoot.sh"
    fi
    if [[ -x "$SCRIPT_DIR/troubleshooting/crash-analyzer.sh" ]]; then
        log "   • Analyze crashes: ./troubleshooting/crash-analyzer.sh"
    fi
    log "   • Check service logs: journalctl -u SRStreamer.service"
    log "   • Review installation log: $LOGFILE"
fi

log ""
log "${BLUE}🔧 Available Scripts:${NC}"
log "   • Master troubleshooter: ./troubleshooting/master-troubleshoot.sh"
log "   • Fix library paths: ./fix-library-path.sh"
log "   • Fix dependencies: ./fix-dependencies.sh"
log "   • Additional setup: ./scripts/master-setup.sh"
log ""
log "${GREEN}✅ Installation process complete!${NC}"