#!/bin/bash
# System Diagnostic Script for Kali Linux Splashtop Installation
# Comprehensive system information gathering for troubleshooting

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPORT_FILE="/tmp/kali-splashtop-diagnostic-$(date +%Y%m%d_%H%M%S).txt"

echo "========================================"
echo "  Kali Linux System Diagnostic Tool"
echo "========================================"
echo ""
echo "📋 This script will gather comprehensive system information"
echo "📝 Report will be saved to: $REPORT_FILE"
echo ""

# Function to add section header to report
add_section() {
    local title="$1"
    echo "" | tee -a "$REPORT_FILE"
    echo "===========================================" | tee -a "$REPORT_FILE"
    echo "$title" | tee -a "$REPORT_FILE"
    echo "===========================================" | tee -a "$REPORT_FILE"
    echo ""
}

# Function to run command and capture output
run_diagnostic() {
    local description="$1"
    local command="$2"
    
    echo "🔍 $description..." | tee -a "$REPORT_FILE"
    echo "Command: $command" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    
    if eval "$command" >> "$REPORT_FILE" 2>&1; then
        echo "✅ $description completed" | tee -a "$REPORT_FILE"
    else
        echo "❌ $description failed" | tee -a "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
}

# Initialize report
echo "Kali Linux Splashtop System Diagnostic Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "Hostname: $(hostname)" >> "$REPORT_FILE"
echo "User: $(whoami)" >> "$REPORT_FILE"

# System Information
add_section "SYSTEM INFORMATION"
run_diagnostic "OS Release Information" "cat /etc/os-release"
run_diagnostic "Kernel Information" "uname -a"
run_diagnostic "System Architecture" "dpkg --print-architecture"
run_diagnostic "CPU Information" "lscpu"
run_diagnostic "Memory Information" "free -h"
run_diagnostic "Disk Space" "df -h"
run_diagnostic "System Uptime" "uptime"

# Package Management
add_section "PACKAGE MANAGEMENT"
run_diagnostic "APT Sources" "cat /etc/apt/sources.list"
run_diagnostic "APT Sources Directory" "find /etc/apt/sources.list.d/ -name '*.list' -exec cat {} \;"
run_diagnostic "Package Cache Status" "apt list --upgradable"
run_diagnostic "Held Packages" "apt-mark showhold"
run_diagnostic "Broken Packages" "dpkg --audit"

# Display System
add_section "DISPLAY SYSTEM"
run_diagnostic "Display Manager Status" "systemctl status display-manager"
run_diagnostic "Active Display Manager" "systemctl list-units --type=service --state=active | grep -E '(gdm|lightdm|sddm|xdm)'"
run_diagnostic "X11 Display" "echo \$DISPLAY"
run_diagnostic "Desktop Session" "echo \$XDG_CURRENT_DESKTOP"
run_diagnostic "Session Type" "echo \$XDG_SESSION_TYPE"
run_diagnostic "Graphics Cards" "lspci | grep -i vga"
run_diagnostic "Graphics Drivers" "lsmod | grep -E '(nouveau|nvidia|amdgpu|radeon|i915)'"

# Network Configuration
add_section "NETWORK CONFIGURATION"
run_diagnostic "Network Interfaces" "ip addr show"
run_diagnostic "Routing Table" "ip route show"
run_diagnostic "DNS Configuration" "cat /etc/resolv.conf"
run_diagnostic "Network Manager Status" "systemctl status NetworkManager"
run_diagnostic "Firewall Status (UFW)" "ufw status verbose"
run_diagnostic "Firewall Status (iptables)" "iptables -L -n"

# Services and Processes
add_section "SERVICES AND PROCESSES"
run_diagnostic "Systemd Services (failed)" "systemctl list-units --failed"
run_diagnostic "Systemd Services (active)" "systemctl list-units --type=service --state=active | head -20"
run_diagnostic "Process List" "ps aux | head -20"
run_diagnostic "SystemD Journal Errors" "journalctl --priority=err --since='1 hour ago' --no-pager"

# User and Permissions
add_section "USER AND PERMISSIONS"
run_diagnostic "Current User Info" "id"
run_diagnostic "Groups" "groups"
run_diagnostic "Sudo Configuration" "sudo -l"
run_diagnostic "PolicyKit Status" "systemctl status polkit"

# Hardware Information
add_section "HARDWARE INFORMATION"
run_diagnostic "USB Devices" "lsusb"
run_diagnostic "PCI Devices" "lspci"
run_diagnostic "Hardware Summary" "lshw -short"
run_diagnostic "Block Devices" "lsblk"

# Audio System
add_section "AUDIO SYSTEM"
run_diagnostic "PulseAudio Status" "systemctl --user status pulseaudio"
run_diagnostic "Audio Devices" "pactl list short sinks"
run_diagnostic "Audio Sources" "pactl list short sources"
run_diagnostic "ALSA Devices" "aplay -l"

# Kali-Specific Information
add_section "KALI LINUX SPECIFIC"
run_diagnostic "Kali Version" "cat /etc/debian_version"
run_diagnostic "Kali Tools" "dpkg -l | grep kali | head -10"
run_diagnostic "Desktop Environment" "dpkg -l | grep -E '(xfce|gnome|kde|mate)' | head -10"

# Environment Variables
add_section "ENVIRONMENT VARIABLES"
run_diagnostic "PATH" "echo \$PATH"
run_diagnostic "LD_LIBRARY_PATH" "echo \$LD_LIBRARY_PATH"
run_diagnostic "Environment" "env | sort"

# Recent System Events
add_section "RECENT SYSTEM EVENTS"
run_diagnostic "Recent Boot Messages" "dmesg | tail -50"
run_diagnostic "Recent System Log" "journalctl --since='1 hour ago' --no-pager | tail -50"
run_diagnostic "Authentication Log" "tail -20 /var/log/auth.log"

# Generate Summary
add_section "DIAGNOSTIC SUMMARY"
{
    echo "📊 System Summary:"
    echo "   OS: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "   Kernel: $(uname -r)"
    echo "   Architecture: $(dpkg --print-architecture)"
    echo "   Desktop: $XDG_CURRENT_DESKTOP"
    echo "   Display Manager: $(systemctl list-units --type=service --state=active | grep -E '(gdm|lightdm|sddm)' | awk '{print $1}' | head -1)"
    echo "   Memory: $(free -h | grep '^Mem:' | awk '{print $2}')"
    echo "   Disk Space: $(df -h / | tail -1 | awk '{print $4}') available"
    echo ""
    echo "🔧 Potential Issues Found:"
    
    # Check for common issues
    local issues_found=false
    
    if ! systemctl is-active --quiet NetworkManager; then
        echo "   ❌ NetworkManager is not active"
        issues_found=true
    fi
    
    if ! systemctl is-active --quiet display-manager; then
        echo "   ❌ Display manager is not active"
        issues_found=true
    fi
    
    if [[ -z "$DISPLAY" ]]; then
        echo "   ⚠️  No display detected (running in console mode?)"
        issues_found=true
    fi
    
    if dpkg --audit | grep -q .; then
        echo "   ⚠️  Broken packages detected"
        issues_found=true
    fi
    
    if ! $issues_found; then
        echo "   ✅ No obvious system issues detected"
    fi
    
    echo ""
    echo "📄 Full report saved to: $REPORT_FILE"
    echo "📤 You can share this report for troubleshooting support"
    
} | tee -a "$REPORT_FILE"

echo ""
echo "========================================"
echo "✅ System diagnostic completed!"
echo "========================================"
echo ""
echo "📄 Report location: $REPORT_FILE"
echo "📊 Report size: $(du -h "$REPORT_FILE" | cut -f1)"
echo ""
echo "💡 Next steps:"
echo "   1. Review the report for any obvious issues"
echo "   2. Run specific diagnostic scripts for detailed analysis"
echo "   3. Share this report when seeking support"
echo ""
echo "🔧 Related troubleshooting scripts:"
if [[ -f "$SCRIPT_DIR/splashtop-diagnostic.sh" ]]; then
    echo "   ./troubleshooting/splashtop-diagnostic.sh"
fi
if [[ -f "$SCRIPT_DIR/network-diagnostic.sh" ]]; then
    echo "   ./troubleshooting/network-diagnostic.sh"
fi
if [[ -f "$SCRIPT_DIR/log-analyzer.sh" ]]; then
    echo "   ./troubleshooting/log-analyzer.sh"
fi