#!/bin/bash
# Splashtop Streamer Crash Analysis Script
# Specialized diagnostic for crash analysis and core dump investigation

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPORT_FILE="/tmp/splashtop-crash-analysis-$(date +%Y%m%d_%H%M%S).txt"

echo "========================================"
echo "  Splashtop Streamer Crash Analyzer"
echo "========================================"
echo ""
echo "💥 This script will analyze Splashtop Streamer crashes and identify causes"
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

# Function for detailed analysis
analyze_crash() {
    local description="$1"
    local command="$2"
    
    echo "🔍 $description..." | tee -a "$REPORT_FILE"
    echo "Command: $command" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    
    if eval "$command" >> "$REPORT_FILE" 2>&1; then
        echo "✅ Analysis completed" | tee -a "$REPORT_FILE"
    else
        echo "❌ Analysis failed or no data found" | tee -a "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
}

# Initialize report
echo "Splashtop Streamer Crash Analysis Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "System: $(uname -a)" >> "$REPORT_FILE"
echo "User: $(whoami)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Immediate Crash Status
add_section "CRASH STATUS ANALYSIS"

echo "🔍 Checking current service status..." | tee -a "$REPORT_FILE"
if systemctl is-active --quiet SRStreamer.service; then
    echo "✅ Service is currently running" | tee -a "$REPORT_FILE"
else
    echo "❌ Service is not running (likely crashed)" | tee -a "$REPORT_FILE"
fi

analyze_crash "Service status details" "systemctl status SRStreamer.service --no-pager -l"
analyze_crash "Service restart count" "systemctl show SRStreamer.service -p NRestarts"
analyze_crash "Last service failure" "systemctl show SRStreamer.service -p ExecMainExitTimestamp"

# Process Analysis
add_section "PROCESS ANALYSIS"

analyze_crash "Current Splashtop processes" "ps aux | grep -E '(SRFeature|SRStreamer|splashtop)' | grep -v grep"
analyze_crash "Process memory usage" "ps -eo pid,ppid,cmd,pmem,rss,vsz | grep -E '(SRFeature|SRStreamer)' | grep -v grep"
analyze_crash "Process open files" "if pgrep SRFeature >/dev/null; then lsof -p \$(pgrep SRFeature) | head -20; else echo 'SRFeature not running'; fi"

# System Resource Analysis
add_section "SYSTEM RESOURCES"

analyze_crash "Memory usage" "free -h"
analyze_crash "Disk space" "df -h /opt/splashtop-streamer/ /tmp/ /var/log/"
analyze_crash "System load" "uptime"
analyze_crash "CPU usage" "top -bn1 | head -20"
analyze_crash "Memory pressure" "dmesg | grep -i 'killed process\\|out of memory\\|oom' | tail -10"

# Crash Logs Analysis
add_section "CRASH LOGS ANALYSIS"

analyze_crash "Recent service failures" "journalctl -u SRStreamer.service --since='24 hours ago' --priority=err --no-pager"
analyze_crash "Service exit codes" "journalctl -u SRStreamer.service --since='24 hours ago' | grep -i 'exited\\|failed\\|killed' | tail -20"
analyze_crash "Segmentation faults" "journalctl --since='24 hours ago' | grep -i 'segfault\\|segmentation' | tail -10"
analyze_crash "Kernel messages" "dmesg | grep -i -E 'splashtop|srfeature|srstreamer|killed|fault' | tail -20"

# Core Dump Analysis
add_section "CORE DUMP INVESTIGATION"

analyze_crash "Core dump configuration" "cat /proc/sys/kernel/core_pattern"
analyze_crash "System core dumps" "find /var/lib/systemd/coredump/ -name '*splashtop*' -o -name '*SRFeature*' -o -name '*SRStreamer*' 2>/dev/null | head -10"
analyze_crash "User core dumps" "find /tmp/ /home/ -name 'core*' -newer /opt/splashtop-streamer/SRFeature 2>/dev/null | head -10"

# Check for core dumps and analyze if found
if find /var/lib/systemd/coredump/ -name '*splashtop*' -o -name '*SRFeature*' 2>/dev/null | grep -q .; then
    analyze_crash "Core dump list" "coredumpctl list | grep -i splashtop"
    analyze_crash "Latest core dump info" "coredumpctl info | head -50"
fi

# Binary Analysis
add_section "BINARY ANALYSIS"

if [[ -f "/opt/splashtop-streamer/SRFeature" ]]; then
    analyze_crash "Binary file info" "file /opt/splashtop-streamer/SRFeature"
    analyze_crash "Binary permissions" "ls -la /opt/splashtop-streamer/SRFeature"
    analyze_crash "Binary size and timestamps" "stat /opt/splashtop-streamer/SRFeature"
    analyze_crash "Library dependencies" "ldd /opt/splashtop-streamer/SRFeature"
    analyze_crash "Missing libraries" "ldd /opt/splashtop-streamer/SRFeature 2>&1 | grep 'not found'"
    analyze_crash "Binary strings (errors)" "strings /opt/splashtop-streamer/SRFeature | grep -i -E 'error|fail|crash|abort|segv' | head -10"
fi

# Environment Analysis
add_section "ENVIRONMENT ANALYSIS"

analyze_crash "Environment variables" "systemctl show-environment"
analyze_crash "Library path" "echo \$LD_LIBRARY_PATH; ls -la /opt/splashtop-streamer/lib* 2>/dev/null || echo 'No library files found'"
analyze_crash "User environment" "sudo -u splashtop-streamer env"

# Display and Graphics Analysis
add_section "DISPLAY SYSTEM ANALYSIS"

analyze_crash "Display configuration" "echo \$DISPLAY; echo \$WAYLAND_DISPLAY"
analyze_crash "Graphics drivers" "lsmod | grep -E '(nvidia|amdgpu|radeon|i915|nouveau)'"
analyze_crash "X server processes" "ps aux | grep -E '(Xorg|Xwayland|gdm|lightdm)' | grep -v grep"
analyze_crash "Graphics memory" "cat /proc/meminfo | grep -i gpu || echo 'No GPU memory info available'"

# Network Analysis (Splashtop is network-dependent)
add_section "NETWORK ANALYSIS"

analyze_crash "Network interfaces" "ip link show"
analyze_crash "Network connectivity" "ping -c 3 8.8.8.8 || echo 'Network connectivity issues'"
analyze_crash "DNS resolution" "nslookup google.com || echo 'DNS issues'"
analyze_crash "Firewall blocking" "iptables -L INPUT | grep -E '(DROP|REJECT)' | head -10"

# File System Analysis
add_section "FILE SYSTEM ANALYSIS"

analyze_crash "Splashtop directory permissions" "ls -la /opt/splashtop-streamer/"
analyze_crash "Config directory status" "ls -la /opt/splashtop-streamer/config/ 2>/dev/null || echo 'Config directory missing'"
analyze_crash "Log directory status" "ls -la /opt/splashtop-streamer/log/ 2>/dev/null || echo 'Log directory missing'"
analyze_crash "Temporary files" "ls -la /tmp/ | grep -i splashtop || echo 'No temp files found'"

# Security and Permissions
add_section "SECURITY ANALYSIS"

analyze_crash "SELinux status" "sestatus 2>/dev/null || echo 'SELinux not available'"
analyze_crash "AppArmor status" "aa-status 2>/dev/null || echo 'AppArmor not available'"
analyze_crash "User capabilities" "sudo -u splashtop-streamer capsh --print || echo 'Capability check failed'"

# Generate Crash Summary and Recommendations
add_section "CRASH ANALYSIS SUMMARY"

{
    echo "💥 Crash Analysis Summary:"
    echo ""
    
    # Analyze common crash causes
    echo "🔍 Common Crash Causes Detected:"
    echo ""
    
    local crash_causes=()
    local recommendations=()
    
    # Check for memory issues
    if dmesg | grep -q -i 'out of memory\|oom'; then
        crash_causes+=("❌ OUT OF MEMORY: System running out of memory")
        recommendations+=("Increase system RAM or add swap space")
        recommendations+=("Kill other memory-intensive processes")
    fi
    
    # Check for missing dependencies
    if ldd /opt/splashtop-streamer/SRFeature 2>&1 | grep -q 'not found'; then
        crash_causes+=("❌ MISSING LIBRARIES: Required libraries not found")
        recommendations+=("Install missing dependencies: ./fix-dependencies.sh")
        recommendations+=("Reinstall package to restore libraries")
    fi
    
    # Check for permission issues
    if [[ ! -x "/opt/splashtop-streamer/SRFeature" ]]; then
        crash_causes+=("❌ PERMISSION DENIED: Binary not executable")
        recommendations+=("Fix permissions: sudo chmod +x /opt/splashtop-streamer/SRFeature")
    fi
    
    # Check for display issues
    if [[ -z "$DISPLAY" && -z "$WAYLAND_DISPLAY" ]]; then
        crash_causes+=("⚠️  NO DISPLAY: Running without display server")
        recommendations+=("Ensure X11 or Wayland is running")
        recommendations+=("Check display manager status")
    fi
    
    # Check for network issues
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        crash_causes+=("⚠️  NETWORK ISSUES: No internet connectivity")
        recommendations+=("Check network configuration")
        recommendations+=("Verify firewall settings")
    fi
    
    # Check for corrupted files
    if [[ ! -f "/opt/splashtop-streamer/SRFeature" ]]; then
        crash_causes+=("❌ MISSING BINARY: Main executable not found")
        recommendations+=("Reinstall package completely")
    fi
    
    # Check service restart frequency
    local restart_count
    restart_count=$(systemctl show SRStreamer.service -p NRestarts --value 2>/dev/null || echo "0")
    if [[ "$restart_count" -gt 5 ]]; then
        crash_causes+=("❌ FREQUENT CRASHES: Service has restarted $restart_count times")
        recommendations+=("Check for system instability")
        recommendations+=("Review system logs for hardware issues")
    fi
    
    if [[ ${#crash_causes[@]} -eq 0 ]]; then
        echo "✅ No obvious crash causes detected in basic checks"
        echo ""
        echo "🔍 Advanced Investigation Needed:"
        echo "   - Core dump analysis required"
        echo "   - Binary debugging with gdb"
        echo "   - Strace analysis of startup"
    else
        for cause in "${crash_causes[@]}"; do
            echo "   $cause"
        done
    fi
    
    echo ""
    echo "🛠️  Recommended Fix Actions:"
    if [[ ${#recommendations[@]} -eq 0 ]]; then
        recommendations+=("Run manual test: sudo -u splashtop-streamer /opt/splashtop-streamer/SRFeature --help")
        recommendations+=("Enable core dumps: echo '/tmp/core.%e.%p' | sudo tee /proc/sys/kernel/core_pattern")
        recommendations+=("Test with strace: sudo strace -f -o /tmp/splashtop.trace /opt/splashtop-streamer/SRFeature")
        recommendations+=("Check for conflicting processes: ps aux | grep -E '(rdp|teamviewer)'")
    fi
    
    for i in "${!recommendations[@]}"; do
        echo "   $((i+1)). ${recommendations[i]}"
    done
    
    echo ""
    echo "🚨 Emergency Recovery Steps:"
    echo "   1. Stop service: sudo systemctl stop SRStreamer.service"
    echo "   2. Test binary manually: sudo -u splashtop-streamer /opt/splashtop-streamer/SRFeature --version"
    echo "   3. Check for core dumps: coredumpctl list | grep splashtop"
    echo "   4. Enable debug logging in service file"
    echo "   5. Reinstall with fallback method: ./install-fallback.sh"
    echo ""
    echo "📊 Technical Details:"
    echo "   - Report: $REPORT_FILE"
    echo "   - System: $(uname -r)"
    echo "   - Memory: $(free -m | grep '^Mem:' | awk '{print $3"/"$2" MB"}')"
    echo "   - Load: $(uptime | awk '{print $NF}')"
    
} | tee -a "$REPORT_FILE"

echo ""
echo "========================================"
echo "✅ Crash analysis completed!"
echo "========================================"
echo ""
echo "📄 Report location: $REPORT_FILE"
echo "📊 Report size: $(du -h "$REPORT_FILE" | cut -f1)"
echo ""
echo "🚨 IMMEDIATE ACTIONS FOR CRASHES:"
echo "   1. Review the crash causes identified above"
echo "   2. Try manual binary execution to reproduce crash"
echo "   3. Check for core dumps with 'coredumpctl list'"
echo "   4. Consider reinstalling with fallback method"
echo ""
echo "🔬 For deeper analysis:"
echo "   ./troubleshooting/log-analyzer.sh      # Analyze all logs"
echo "   ./troubleshooting/dependency-check.sh  # Verify all dependencies"
echo ""