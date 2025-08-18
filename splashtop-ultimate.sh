#!/bin/bash
# Splashtop Ultimate Installation, Troubleshooting, and Management Script
# Complete solution for Kali Linux 2025.2 with integrated error handling and diagnostics

set -e
trap 'handle_error $? $LINENO' ERR

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
LOGFILE="/tmp/splashtop-ultimate-$(date +%Y%m%d_%H%M%S).log"
REPORT_DIR="/tmp/splashtop-reports-$(date +%Y%m%d_%H%M%S)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global error tracking
ERROR_COUNT=0
CRITICAL_ERRORS=()
WARNINGS=()

# Enhanced logging function
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

# Error handler
handle_error() {
    local exit_code=$1
    local line_number=$2
    ERROR_COUNT=$((ERROR_COUNT + 1))
    
    log "${RED}❌ ERROR $ERROR_COUNT at line $line_number (exit code: $exit_code)${NC}"
    CRITICAL_ERRORS+=("Line $line_number: Exit code $exit_code")
    
    # Don't exit immediately, continue with recovery
    set +e
    
    # Run diagnostics on error
    if [[ $ERROR_COUNT -eq 1 ]]; then
        log "${YELLOW}🔍 Running automatic diagnostics...${NC}"
        run_diagnostics "error_triggered"
    fi
    
    # Reset error handling
    set -e
    trap 'handle_error $? $LINENO' ERR
}

# Warning function
warn() {
    log "${YELLOW}⚠️  WARNING: $1${NC}"
    WARNINGS+=("$1")
}

# System check functions
check_system() {
    log "${BLUE}🔍 System compatibility check...${NC}"
    
    # Check if root
    if [[ $EUID -ne 0 ]]; then
        log "${RED}❌ This script must be run as root (use sudo)${NC}"
        exit 1
    fi
    
    # Check Kali Linux
    if ! grep -q "Kali" /etc/os-release 2>/dev/null; then
        warn "Not running on Kali Linux"
        log "Current system: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2 || echo 'Unknown')"
    fi
    
    # Check architecture
    if [[ "$(dpkg --print-architecture)" != "amd64" ]]; then
        warn "Architecture is not amd64: $(dpkg --print-architecture)"
    fi
    
    # Check available space
    local available_space=$(df / | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 1048576 ]]; then  # Less than 1GB
        warn "Low disk space: $(($available_space/1024))MB available"
    fi
    
    # Check memory
    local available_memory=$(free -m | grep '^Mem:' | awk '{print $7}')
    if [[ $available_memory -lt 512 ]]; then
        warn "Low available memory: ${available_memory}MB"
    fi
    
    log "${GREEN}✅ System check completed${NC}"
}

# Network connectivity check
check_network() {
    log "${BLUE}🌐 Network connectivity check...${NC}"
    
    if ! ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        warn "No internet connectivity detected"
        return 1
    fi
    
    if ! nslookup google.com >/dev/null 2>&1; then
        warn "DNS resolution issues detected"
        return 1
    fi
    
    log "${GREEN}✅ Network connectivity verified${NC}"
    return 0
}

# Package installation with error recovery
install_package() {
    local attempt=1
    local max_attempts=3
    
    while [[ $attempt -le $max_attempts ]]; do
        log "${BLUE}📦 Installation attempt $attempt/$max_attempts${NC}"
        
        # Update package lists
        if ! apt update >> "$LOGFILE" 2>&1; then
            warn "Failed to update package lists on attempt $attempt"
        fi
        
        # Try standard installation
        if dpkg -i "$SCRIPT_DIR/Splashtop_Streamer_Kali_amd64.deb" >> "$LOGFILE" 2>&1; then
            log "${GREEN}✅ Package installed successfully${NC}"
            return 0
        fi
        
        # Fix dependencies
        apt-get install -f -y >> "$LOGFILE" 2>&1 || true
        
        # Try fallback method on final attempt
        if [[ $attempt -eq $max_attempts && -x "$SCRIPT_DIR/install-fallback.sh" ]]; then
            log "${YELLOW}🔄 Trying fallback installation method...${NC}"
            if "$SCRIPT_DIR/install-fallback.sh" >> "$LOGFILE" 2>&1; then
                log "${GREEN}✅ Fallback installation successful${NC}"
                return 0
            fi
        fi
        
        attempt=$((attempt + 1))
        sleep 2
    done
    
    log "${RED}❌ Package installation failed after $max_attempts attempts${NC}"
    return 1
}

# Binary and permissions fix with verification
fix_binaries() {
    log "${BLUE}🔧 Fixing binary permissions and library paths...${NC}"
    
    local binaries=(
        "/opt/splashtop-streamer/SRFeature"
        "/opt/splashtop-streamer/SRStreamer" 
        "/opt/splashtop-streamer/SRAgent"
        "/usr/bin/splashtop-streamer"
    )
    
    for binary in "${binaries[@]}"; do
        if [[ -f "$binary" ]]; then
            chmod +x "$binary" 2>/dev/null || warn "Failed to make $binary executable"
            if [[ -x "$binary" ]]; then
                log "  ✅ $binary is executable"
            else
                warn "$binary is not executable after chmod"
            fi
        else
            warn "$binary not found"
        fi
    done
    
    # Setup library path
    echo "/opt/splashtop-streamer" > /etc/ld.so.conf.d/splashtop.conf
    ldconfig >> "$LOGFILE" 2>&1
    
    # Create system library symlinks
    local libs=(
        "libcelt0.so.0"
        "libmsquic.so.2"
    )
    
    for lib in "${libs[@]}"; do
        if [[ -f "/opt/splashtop-streamer/$lib" ]]; then
            ln -sf "/opt/splashtop-streamer/$lib" "/usr/lib/x86_64-linux-gnu/$lib" 2>/dev/null || true
        fi
    done
    
    log "${GREEN}✅ Binary configuration completed${NC}"
}

# Service management with retry logic
manage_service() {
    local action="$1"
    local max_attempts=3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log "${BLUE}🔄 Service $action attempt $attempt/$max_attempts${NC}"
        
        case $action in
            "start")
                systemctl daemon-reload >> "$LOGFILE" 2>&1
                if systemctl start SRStreamer.service >> "$LOGFILE" 2>&1; then
                    sleep 3
                    if systemctl is-active --quiet SRStreamer.service; then
                        log "${GREEN}✅ Service started successfully${NC}"
                        return 0
                    fi
                fi
                ;;
            "restart")
                systemctl daemon-reload >> "$LOGFILE" 2>&1
                if systemctl restart SRStreamer.service >> "$LOGFILE" 2>&1; then
                    sleep 3
                    if systemctl is-active --quiet SRStreamer.service; then
                        log "${GREEN}✅ Service restarted successfully${NC}"
                        return 0
                    fi
                fi
                ;;
        esac
        
        # Log failure details
        log "Service $action failed on attempt $attempt:"
        systemctl status SRStreamer.service --no-pager | head -10 | tee -a "$LOGFILE"
        
        attempt=$((attempt + 1))
        
        # Try fixes between attempts
        if [[ $attempt -le $max_attempts ]]; then
            log "${YELLOW}🔧 Applying fixes before retry...${NC}"
            fix_binaries
            sleep 2
        fi
    done
    
    warn "Service $action failed after $max_attempts attempts"
    return 1
}

# Comprehensive diagnostics
run_diagnostics() {
    local context="${1:-manual}"
    mkdir -p "$REPORT_DIR"
    
    log_section "COMPREHENSIVE DIAGNOSTICS ($context)"
    
    # System information
    {
        echo "=== SYSTEM INFORMATION ==="
        echo "Date: $(date)"
        echo "System: $(uname -a)"
        echo "Distribution: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'=' -f2)"
        echo "Architecture: $(dpkg --print-architecture)"
        echo "Memory: $(free -h | grep '^Mem:')"
        echo "Disk: $(df -h / | tail -1)"
        echo ""
    } > "$REPORT_DIR/system-info.txt"
    
    # Package status
    {
        echo "=== PACKAGE STATUS ==="
        if dpkg -l | grep splashtop-streamer; then
            echo "Package installed"
            dpkg -L splashtop-streamer | head -20
        else
            echo "Package not installed"
        fi
        echo ""
    } > "$REPORT_DIR/package-status.txt"
    
    # Service analysis
    {
        echo "=== SERVICE ANALYSIS ==="
        echo "Status:"
        systemctl status SRStreamer.service --no-pager || true
        echo ""
        echo "Recent logs:"
        journalctl -u SRStreamer.service --since='1 hour ago' --no-pager | tail -50
        echo ""
    } > "$REPORT_DIR/service-analysis.txt"
    
    # Binary analysis
    {
        echo "=== BINARY ANALYSIS ==="
        local main_binary="/opt/splashtop-streamer/SRFeature"
        if [[ -f "$main_binary" ]]; then
            echo "Binary exists: $main_binary"
            echo "Permissions: $(ls -la "$main_binary")"
            echo "File type: $(file "$main_binary")"
            echo ""
            echo "Library dependencies:"
            ldd "$main_binary" 2>&1 || echo "ldd failed"
            echo ""
            echo "Missing libraries:"
            ldd "$main_binary" 2>&1 | grep "not found" || echo "None"
        else
            echo "Main binary not found: $main_binary"
        fi
        echo ""
    } > "$REPORT_DIR/binary-analysis.txt"
    
    # Network analysis
    {
        echo "=== NETWORK ANALYSIS ==="
        echo "Interfaces:"
        ip addr show
        echo ""
        echo "Routing:"
        ip route show
        echo ""
        echo "Connectivity:"
        ping -c 2 8.8.8.8 2>&1 || echo "No internet connectivity"
        echo ""
        echo "DNS:"
        nslookup google.com 2>&1 || echo "DNS issues"
        echo ""
        echo "Firewall:"
        ufw status verbose 2>/dev/null || echo "UFW not available"
        echo ""
    } > "$REPORT_DIR/network-analysis.txt"
    
    # Log analysis with intelligent pattern detection
    {
        echo "=== LOG ANALYSIS ==="
        echo "Recent system errors:"
        journalctl --since='1 hour ago' --priority=err --no-pager | tail -20
        echo ""
        echo "Crash patterns:"
        journalctl -u SRStreamer.service --since='24 hours ago' --no-pager | grep -i -E "(killed|segfault|crashed|error|failed)" | tail -20
        echo ""
        echo "Memory issues:"
        dmesg | grep -i -E "(out of memory|oom|killed)" | tail -10
        echo ""
    } > "$REPORT_DIR/log-analysis.txt"
    
    # Create archive
    cd /tmp
    tar -czf "splashtop-diagnostics-$(date +%Y%m%d_%H%M%S).tar.gz" "$(basename "$REPORT_DIR")" 2>/dev/null
    
    log "${GREEN}✅ Diagnostics completed${NC}"
    log "📁 Reports directory: $REPORT_DIR"
}

# Intelligent issue detection and auto-fix
auto_fix_issues() {
    log_section "INTELLIGENT ISSUE DETECTION & AUTO-FIX"
    
    local fixes_applied=0
    
    # Fix 1: Binary permissions
    if [[ ! -x "/opt/splashtop-streamer/SRFeature" ]]; then
        log "${YELLOW}🔧 Fixing binary permissions...${NC}"
        fix_binaries
        fixes_applied=$((fixes_applied + 1))
    fi
    
    # Fix 2: Missing libraries
    local missing_libs=$(ldd /opt/splashtop-streamer/SRFeature 2>&1 | grep "not found" | wc -l)
    if [[ $missing_libs -gt 0 ]]; then
        log "${YELLOW}🔧 Fixing missing libraries ($missing_libs found)...${NC}"
        
        # Update library cache
        ldconfig
        
        # Create symlinks
        if [[ -f "/opt/splashtop-streamer/libcelt0.so.0" ]]; then
            ln -sf /opt/splashtop-streamer/libcelt0.so.0 /usr/lib/x86_64-linux-gnu/libcelt0.so.0
        fi
        if [[ -f "/opt/splashtop-streamer/libmsquic.so.2" ]]; then
            ln -sf /opt/splashtop-streamer/libmsquic.so.2 /usr/lib/x86_64-linux-gnu/libmsquic.so.2
        fi
        
        fixes_applied=$((fixes_applied + 1))
    fi
    
    # Fix 3: Service configuration
    if ! systemctl is-enabled SRStreamer.service >/dev/null 2>&1; then
        log "${YELLOW}🔧 Enabling service...${NC}"
        systemctl enable SRStreamer.service
        fixes_applied=$((fixes_applied + 1))
    fi
    
    # Fix 4: Firewall rules
    if command -v ufw >/dev/null 2>&1; then
        if ! ufw status | grep -q "443"; then
            log "${YELLOW}🔧 Adding firewall rules...${NC}"
            ufw allow 443/tcp >/dev/null 2>&1 || true
            ufw allow 6783/tcp >/dev/null 2>&1 || true
            fixes_applied=$((fixes_applied + 1))
        fi
    fi
    
    # Fix 5: PulseAudio (for audio support)
    if systemctl is-active --quiet SRStreamer.service; then
        if journalctl -u SRStreamer.service --since='5 minutes ago' | grep -q "pa_context_connect.*failed"; then
            log "${YELLOW}🔧 Configuring PulseAudio...${NC}"
            systemctl --user enable pulseaudio >/dev/null 2>&1 || true
            pulseaudio --start >/dev/null 2>&1 || true
            fixes_applied=$((fixes_applied + 1))
        fi
    fi
    
    log "${GREEN}✅ Auto-fix completed: $fixes_applied fixes applied${NC}"
}

# Enhanced status check
check_status() {
    log_section "COMPREHENSIVE STATUS CHECK"
    
    local overall_status="UNKNOWN"
    local issues=()
    local good=()
    
    # Check package
    if dpkg -l | grep -q splashtop-streamer; then
        good+=("✅ Package installed")
    else
        issues+=("❌ Package not installed")
    fi
    
    # Check binary
    if [[ -x "/opt/splashtop-streamer/SRFeature" ]]; then
        good+=("✅ Main binary executable")
    else
        issues+=("❌ Main binary not executable")
    fi
    
    # Check service
    if systemctl is-active --quiet SRStreamer.service; then
        good+=("✅ Service running")
        overall_status="RUNNING"
    else
        issues+=("❌ Service not running")
        if [[ "$overall_status" == "UNKNOWN" ]]; then
            overall_status="FAILED"
        fi
    fi
    
    # Check libraries
    local missing_libs=0
    if [[ -f "/opt/splashtop-streamer/SRFeature" ]]; then
        missing_libs=$(ldd /opt/splashtop-streamer/SRFeature 2>&1 | grep "not found" | wc -l)
        if [[ $missing_libs -eq 0 ]]; then
            good+=("✅ All libraries found")
        else
            issues+=("❌ $missing_libs missing libraries")
        fi
    fi
    
    # Check network
    if check_network >/dev/null 2>&1; then
        good+=("✅ Network connectivity")
    else
        issues+=("❌ Network issues")
    fi
    
    # Display results
    log "${PURPLE}📊 SYSTEM STATUS: $overall_status${NC}"
    log ""
    
    if [[ ${#good[@]} -gt 0 ]]; then
        log "${GREEN}Good:${NC}"
        for item in "${good[@]}"; do
            log "  $item"
        done
    fi
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log ""
        log "${RED}Issues:${NC}"
        for item in "${issues[@]}"; do
            log "  $item"
        done
    fi
    
    # Service details if running
    if systemctl is-active --quiet SRStreamer.service; then
        log ""
        log "${BLUE}Service Details:${NC}"
        log "  PID: $(systemctl show SRStreamer.service -p MainPID --value)"
        log "  Memory: $(ps -o pid,ppid,pmem,rss,cmd -C SRFeature 2>/dev/null | tail -1 | awk '{print $4"KB"}' || echo 'N/A')"
        log "  Uptime: $(systemctl show SRStreamer.service -p ActiveEnterTimestamp --value | cut -d' ' -f2-)"
    fi
    
    return ${#issues[@]}
}

# Interactive menu
show_menu() {
    clear
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║            SPLASHTOP ULTIMATE MANAGEMENT TOOL               ║${NC}"
    echo -e "${CYAN}║                  Kali Linux 2025.2 Edition                  ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}1.${NC} 🚀 Complete Installation (Recommended for new installs)"
    echo -e "${BLUE}2.${NC} 🔧 Fix Existing Installation (For troubleshooting)"
    echo -e "${BLUE}3.${NC} 🔍 Run Diagnostics Only"
    echo -e "${BLUE}4.${NC} 📊 Check Status"
    echo -e "${BLUE}5.${NC} 🔄 Service Management"
    echo -e "${BLUE}6.${NC} 🛠️  Advanced Options"
    echo -e "${BLUE}7.${NC} 📚 Help & Information"
    echo -e "${BLUE}8.${NC} 🚪 Exit"
    echo ""
    echo -e "System: ${GREEN}$(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"')${NC}"
    echo -e "Status: $(systemctl is-active --quiet SRStreamer.service && echo -e "${GREEN}Service Running${NC}" || echo -e "${RED}Service Not Running${NC}")"
    echo ""
    read -p "Select option (1-8): " choice
}

# Main installation workflow
complete_installation() {
    log_section "COMPLETE SPLASHTOP INSTALLATION"
    
    # Pre-installation checks
    check_system
    check_network
    
    # Installation steps
    if install_package; then
        fix_binaries
        
        # Try to start service
        if ! manage_service "start"; then
            log "${YELLOW}🔧 Service start failed, running auto-fix...${NC}"
            auto_fix_issues
            manage_service "restart"
        fi
        
        # Final verification
        if check_status; then
            log "${GREEN}🎉 Installation completed successfully!${NC}"
        else
            log "${YELLOW}⚠️  Installation completed with warnings${NC}"
            run_diagnostics "post_install"
        fi
    else
        log "${RED}❌ Installation failed${NC}"
        run_diagnostics "install_failed"
    fi
}

# Fix existing installation
fix_installation() {
    log_section "FIXING EXISTING INSTALLATION"
    
    run_diagnostics "pre_fix"
    auto_fix_issues
    
    if manage_service "restart"; then
        log "${GREEN}✅ Fix completed successfully${NC}"
    else
        log "${YELLOW}⚠️  Some issues may remain${NC}"
        run_diagnostics "post_fix"
    fi
    
    check_status
}

# Service management menu
service_management() {
    echo ""
    echo -e "${BLUE}🔄 Service Management:${NC}"
    echo "1. Start service"
    echo "2. Stop service" 
    echo "3. Restart service"
    echo "4. View logs"
    echo "5. Back to main menu"
    echo ""
    read -p "Select action (1-5): " service_action
    
    case $service_action in
        1) manage_service "start" ;;
        2) systemctl stop SRStreamer.service && log "${GREEN}✅ Service stopped${NC}" ;;
        3) manage_service "restart" ;;
        4) journalctl -u SRStreamer.service -f ;;
        5) return ;;
        *) warn "Invalid option" ;;
    esac
}

# Advanced options menu
advanced_options() {
    echo ""
    echo -e "${BLUE}🛠️  Advanced Options:${NC}"
    echo "1. Force reinstall package"
    echo "2. Reset all configurations"
    echo "3. Manual binary test"
    echo "4. Create diagnostic archive"
    echo "5. View installation log"
    echo "6. Back to main menu"
    echo ""
    read -p "Select option (1-6): " advanced_choice
    
    case $advanced_choice in
        1) 
            systemctl stop SRStreamer.service || true
            dpkg --purge splashtop-streamer || true
            install_package
            fix_binaries
            manage_service "start"
            ;;
        2)
            systemctl stop SRStreamer.service || true
            rm -rf /opt/splashtop-streamer/config/* || true
            systemctl daemon-reload
            manage_service "start"
            ;;
        3)
            log "Testing binary manually:"
            sudo -u splashtop-streamer env LD_LIBRARY_PATH=/opt/splashtop-streamer /opt/splashtop-streamer/SRFeature --version || true
            ;;
        4)
            run_diagnostics "manual"
            ;;
        5)
            less "$LOGFILE"
            ;;
        6)
            return
            ;;
        *)
            warn "Invalid option"
            ;;
    esac
}

# Help and information
show_help() {
    echo ""
    echo -e "${CYAN}📚 SPLASHTOP ULTIMATE HELP${NC}"
    echo ""
    echo -e "${BLUE}Common Issues:${NC}"
    echo "• Service crashes with 203/EXEC: Binary permission issue - use option 2"
    echo "• Missing libraries: Library path issue - use option 2" 
    echo "• Connection refused: Network/firewall issue - check diagnostics"
    echo "• PulseAudio warnings: Audio system issue (doesn't affect functionality)"
    echo ""
    echo -e "${BLUE}Files and Locations:${NC}"
    echo "• Main binary: /opt/splashtop-streamer/SRFeature"
    echo "• Service file: /lib/systemd/system/SRStreamer.service"
    echo "• Configuration: /opt/splashtop-streamer/config/"
    echo "• Logs: journalctl -u SRStreamer.service"
    echo ""
    echo -e "${BLUE}Network Requirements:${NC}"
    echo "• Port 443/tcp (HTTPS - outbound and inbound)"
    echo "• Port 6783/tcp (Splashtop protocol - inbound)"
    echo "• Internet connectivity for deployment"
    echo ""
    echo -e "${BLUE}Usage After Installation:${NC}"
    echo "• Deploy: splashtop-streamer deploy [CODE]"
    echo "• Configure: splashtop-streamer config"
    echo "• Help: splashtop-streamer help"
    echo ""
    read -p "Press Enter to continue..."
}

# Final status report
final_report() {
    log_section "FINAL STATUS REPORT"
    
    # Error summary
    if [[ $ERROR_COUNT -gt 0 ]]; then
        log "${RED}❌ Total errors encountered: $ERROR_COUNT${NC}"
        for error in "${CRITICAL_ERRORS[@]}"; do
            log "  • $error"
        done
    fi
    
    # Warning summary  
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        log "${YELLOW}⚠️  Total warnings: ${#WARNINGS[@]}${NC}"
        for warning in "${WARNINGS[@]}"; do
            log "  • $warning"
        done
    fi
    
    # Current status
    check_status >/dev/null
    local status_exit=$?
    
    if [[ $status_exit -eq 0 ]]; then
        log "${GREEN}🎉 OVERALL STATUS: SUCCESS${NC}"
        log "   Splashtop Streamer is operational!"
    else
        log "${YELLOW}⚠️  OVERALL STATUS: ISSUES DETECTED${NC}"
        log "   Review diagnostics for details"
    fi
    
    log ""
    log "${BLUE}📁 Generated files:${NC}"
    log "   • Installation log: $LOGFILE"
    log "   • Diagnostics: $REPORT_DIR"
    log ""
    log "${BLUE}⏰ Session completed: $(date)${NC}"
}

# Main execution
main() {
    # Initialize
    mkdir -p "$REPORT_DIR"
    touch "$LOGFILE"
    
    log "${CYAN}Splashtop Ultimate Tool Started: $(date)${NC}"
    log "Log file: $LOGFILE"
    log "Reports: $REPORT_DIR"
    log ""
    
    # Check if running non-interactively with parameters
    if [[ $# -gt 0 ]]; then
        case $1 in
            "install") complete_installation ;;
            "fix") fix_installation ;;
            "diagnostic") run_diagnostics "cli" ;;
            "status") check_status ;;
            *) log "${RED}Unknown parameter: $1${NC}"; exit 1 ;;
        esac
        final_report
        exit 0
    fi
    
    # Interactive mode
    while true; do
        show_menu
        
        case $choice in
            1) complete_installation ;;
            2) fix_installation ;;
            3) run_diagnostics "manual" ;;
            4) check_status ;;
            5) service_management ;;
            6) advanced_options ;;
            7) show_help ;;
            8) 
                log "${BLUE}👋 Goodbye!${NC}"
                final_report
                exit 0
                ;;
            *) warn "Invalid option: $choice" ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Script starts here
main "$@"