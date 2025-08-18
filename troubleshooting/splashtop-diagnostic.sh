#!/bin/bash
# Splashtop Streamer Diagnostic Script
# Comprehensive troubleshooting for Splashtop installation and service issues

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPORT_FILE="/tmp/splashtop-diagnostic-$(date +%Y%m%d_%H%M%S).txt"

echo "========================================"
echo "  Splashtop Streamer Diagnostic Tool"
echo "========================================"
echo ""
echo "🔍 This script will analyze Splashtop Streamer installation and identify issues"
echo "📝 Report will be saved to: $REPORT_FILE"
echo ""

# Function to add section header
add_section() {
    local title="$1"
    echo "" | tee -a "$REPORT_FILE"
    echo "===========================================" | tee -a "$REPORT_FILE"
    echo "$title" | tee -a "$REPORT_FILE"
    echo "===========================================" | tee -a "$REPORT_FILE"
    echo ""
}

# Function to check and report status
check_item() {
    local description="$1"
    local command="$2"
    local expected="$3"  # Optional expected result
    
    echo -n "🔍 $description... " | tee -a "$REPORT_FILE"
    
    if result=$(eval "$command" 2>/dev/null); then
        if [[ -n "$expected" && "$result" != "$expected" ]]; then
            echo "⚠️  WARNING: $result" | tee -a "$REPORT_FILE"
            return 1
        else
            echo "✅ OK" | tee -a "$REPORT_FILE"
            [[ -n "$result" ]] && echo "   Result: $result" >> "$REPORT_FILE"
            return 0
        fi
    else
        echo "❌ FAILED" | tee -a "$REPORT_FILE"
        echo "   Command: $command" >> "$REPORT_FILE"
        return 1
    fi
}

# Function for detailed analysis
analyze_item() {
    local description="$1"
    local command="$2"
    
    echo "🔍 $description..." | tee -a "$REPORT_FILE"
    echo "Command: $command" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    
    if eval "$command" >> "$REPORT_FILE" 2>&1; then
        echo "✅ Analysis completed" | tee -a "$REPORT_FILE"
    else
        echo "❌ Analysis failed" | tee -a "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
}

# Initialize report
echo "Splashtop Streamer Diagnostic Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "System: $(uname -a)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Package Installation Status
add_section "PACKAGE INSTALLATION STATUS"

check_item "Splashtop package installed" "dpkg -l | grep -q splashtop-streamer"
if dpkg -l | grep -q splashtop-streamer; then
    analyze_item "Package details" "dpkg -l | grep splashtop-streamer"
    analyze_item "Package files" "dpkg -L splashtop-streamer | head -20"
else
    echo "❌ Splashtop package is not installed!" | tee -a "$REPORT_FILE"
fi

check_item "Package configuration status" "dpkg --get-selections | grep splashtop-streamer"

# Binary and File Checks
add_section "BINARY AND FILE VERIFICATION"

check_item "Main binary exists" "test -f /opt/splashtop-streamer/SRFeature"
check_item "Streamer binary exists" "test -f /opt/splashtop-streamer/SRStreamer"
check_item "User binary link exists" "test -f /usr/bin/splashtop-streamer"
check_item "User binary executable" "test -x /usr/bin/splashtop-streamer"

if [[ -f "/opt/splashtop-streamer/SRFeature" ]]; then
    analyze_item "Binary permissions" "ls -la /opt/splashtop-streamer/SRFeature"
    analyze_item "Binary dependencies" "ldd /opt/splashtop-streamer/SRFeature | head -10"
fi

# User and Group Setup
add_section "USER AND GROUP CONFIGURATION"

check_item "Splashtop user exists" "id splashtop-streamer >/dev/null 2>&1"
check_item "Splashtop group exists" "getent group splashtop-streamer >/dev/null 2>&1"

if id splashtop-streamer >/dev/null 2>&1; then
    analyze_item "User details" "id splashtop-streamer"
    analyze_item "User home directory" "ls -la /opt/splashtop-streamer/"
fi

# Service Configuration
add_section "SYSTEMD SERVICE STATUS"

check_item "Service file exists" "test -f /lib/systemd/system/SRStreamer.service"
if [[ -f "/lib/systemd/system/SRStreamer.service" ]]; then
    analyze_item "Service file content" "cat /lib/systemd/system/SRStreamer.service"
fi

check_item "Service enabled" "systemctl is-enabled SRStreamer.service >/dev/null 2>&1"
check_item "Service active" "systemctl is-active SRStreamer.service >/dev/null 2>&1"

analyze_item "Service status" "systemctl status SRStreamer.service --no-pager"

# Service Logs Analysis
add_section "SERVICE LOGS ANALYSIS"

analyze_item "Recent service logs" "journalctl -u SRStreamer.service --since='1 hour ago' --no-pager"
analyze_item "Service startup errors" "journalctl -u SRStreamer.service --since='24 hours ago' --priority=err --no-pager"

# Process Analysis
add_section "PROCESS ANALYSIS"

analyze_item "Splashtop processes" "ps aux | grep -i splashtop | grep -v grep"
analyze_item "Process tree" "pstree -p | grep -i splash || echo 'No Splashtop processes found'"

# Network and Connectivity
add_section "NETWORK ANALYSIS"

analyze_item "Network interfaces" "ip addr show"
analyze_item "Listening ports" "netstat -tlnp | grep -E '(splashtop|SRFeature|SRStreamer)' || echo 'No Splashtop ports found'"
analyze_item "Open ports" "ss -tlnp | head -20"

# Dependencies Check
add_section "DEPENDENCIES VERIFICATION"

check_item "PolicyKit available" "which pkexec >/dev/null 2>&1 || systemctl status polkit >/dev/null 2>&1"
check_item "PulseAudio available" "which pulseaudio >/dev/null 2>&1"
check_item "FUSE available" "which fusermount >/dev/null 2>&1"
check_item "X11 utilities available" "which xrandr >/dev/null 2>&1"

analyze_item "Missing dependencies" "apt list --installed | grep -E '(polkit|pulseaudio|fuse|x11)' || echo 'Some dependencies may be missing'"

# Configuration Files
add_section "CONFIGURATION ANALYSIS"

analyze_item "Splashtop config directory" "ls -la /opt/splashtop-streamer/config/ 2>/dev/null || echo 'Config directory not found'"
analyze_item "Log directory" "ls -la /opt/splashtop-streamer/log/ 2>/dev/null || echo 'Log directory not found'"

if [[ -d "/opt/splashtop-streamer/log" ]]; then
    analyze_item "Recent log files" "find /opt/splashtop-streamer/log -name '*.log' -mtime -1 -exec ls -la {} \;"
fi

# Desktop Integration
add_section "DESKTOP INTEGRATION"

check_item "Desktop file exists" "test -f /usr/share/applications/com.splashtop.streamer.desktop"
if [[ -f "/usr/share/applications/com.splashtop.streamer.desktop" ]]; then
    analyze_item "Desktop file content" "cat /usr/share/applications/com.splashtop.streamer.desktop"
fi

analyze_item "Icon files" "find /usr/share/icons -name '*splashtop*' -o -name '*streamer*' | head -10"

# Firewall and Security
add_section "FIREWALL AND SECURITY"

analyze_item "UFW status" "ufw status verbose 2>/dev/null || echo 'UFW not available'"
analyze_item "IPtables rules" "iptables -L INPUT -n | head -10"
analyze_item "SELinux status" "sestatus 2>/dev/null || echo 'SELinux not available'"

# Display Manager Integration
add_section "DISPLAY MANAGER INTEGRATION"

analyze_item "Current display manager" "systemctl status display-manager --no-pager"
analyze_item "Display manager config files" "find /etc -name '*splashtop*' 2>/dev/null | head -10"

if [[ -d "/etc/lightdm/lightdm.conf.d" ]]; then
    analyze_item "LightDM Splashtop config" "cat /etc/lightdm/lightdm.conf.d/95-splashtop.conf 2>/dev/null || echo 'No Splashtop LightDM config found'"
fi

# Troubleshooting Recommendations
add_section "TROUBLESHOOTING RECOMMENDATIONS"

{
    echo "🔧 Automated Issue Analysis:"
    echo ""
    
    local issues_found=false
    local recommendations=()
    
    # Check if package is installed
    if ! dpkg -l | grep -q splashtop-streamer; then
        echo "❌ CRITICAL: Splashtop package is not installed"
        recommendations+=("Install the package: sudo dpkg -i Splashtop_Streamer_Kali_amd64.deb")
        issues_found=true
    fi
    
    # Check if service is running
    if ! systemctl is-active --quiet SRStreamer.service; then
        echo "❌ CRITICAL: SRStreamer service is not running"
        recommendations+=("Start the service: sudo systemctl start SRStreamer.service")
        recommendations+=("Check service logs: journalctl -u SRStreamer.service -f")
        issues_found=true
    fi
    
    # Check if binary exists
    if [[ ! -f "/opt/splashtop-streamer/SRFeature" ]]; then
        echo "❌ CRITICAL: Main binary is missing"
        recommendations+=("Reinstall the package with --force-overwrite option")
        issues_found=true
    fi
    
    # Check if user exists
    if ! id splashtop-streamer >/dev/null 2>&1; then
        echo "❌ ERROR: splashtop-streamer user is missing"
        recommendations+=("Run package configuration: sudo dpkg-reconfigure splashtop-streamer")
        issues_found=true
    fi
    
    # Check permissions
    if [[ -f "/opt/splashtop-streamer/SRFeature" ]] && [[ ! -x "/opt/splashtop-streamer/SRFeature" ]]; then
        echo "❌ ERROR: Main binary is not executable"
        recommendations+=("Fix permissions: sudo chmod +x /opt/splashtop-streamer/SRFeature")
        issues_found=true
    fi
    
    # Check dependencies
    if ! which pkexec >/dev/null 2>&1 && ! systemctl status polkit >/dev/null 2>&1; then
        echo "⚠️  WARNING: PolicyKit not found"
        recommendations+=("Install PolicyKit: sudo apt install polkitd")
        issues_found=true
    fi
    
    if ! $issues_found; then
        echo "✅ No critical issues detected"
        echo ""
        echo "💡 If Splashtop is still not working, try:"
        recommendations+=("Restart the service: sudo systemctl restart SRStreamer.service")
        recommendations+=("Check firewall settings: sudo ufw status")
        recommendations+=("Verify network connectivity")
    fi
    
    echo ""
    echo "📋 Recommended Actions:"
    for i in "${!recommendations[@]}"; do
        echo "   $((i+1)). ${recommendations[i]}"
    done
    
    echo ""
    echo "🔍 Advanced Troubleshooting:"
    echo "   - Review full service logs: journalctl -u SRStreamer.service --since='24 hours ago'"
    echo "   - Test binary directly: sudo -u splashtop-streamer /opt/splashtop-streamer/SRFeature"
    echo "   - Check library dependencies: ldd /opt/splashtop-streamer/SRFeature"
    echo "   - Verify network ports: sudo netstat -tlnp | grep SRFeature"
    echo ""
    echo "📞 Support Information:"
    echo "   - Report location: $REPORT_FILE"
    echo "   - System: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2) $(uname -m)"
    echo "   - Package version: $(dpkg -l | grep splashtop-streamer | awk '{print $3}' || echo 'Not installed')"
    
} | tee -a "$REPORT_FILE"

echo ""
echo "========================================"
echo "✅ Splashtop diagnostic completed!"
echo "========================================"
echo ""
echo "📄 Report location: $REPORT_FILE"
echo "📊 Report size: $(du -h "$REPORT_FILE" | cut -f1)"
echo ""
echo "💡 Next steps:"
echo "   1. Review the troubleshooting recommendations above"
echo "   2. Follow the suggested actions to resolve issues"
echo "   3. Run this script again after making changes"
echo "   4. If issues persist, share this report for support"
echo ""