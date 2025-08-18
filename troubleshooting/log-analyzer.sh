#!/bin/bash
# Log Analysis Script for Splashtop Streamer
# Comprehensive log collection and intelligent analysis

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPORT_FILE="/tmp/splashtop-logs-analysis-$(date +%Y%m%d_%H%M%S).txt"
LOG_ARCHIVE="/tmp/splashtop-logs-$(date +%Y%m%d_%H%M%S).tar.gz"

echo "========================================"
echo "  Splashtop Log Analysis Tool"
echo "========================================"
echo ""
echo "📋 This script will collect and analyze all Splashtop-related logs"
echo "📝 Analysis report: $REPORT_FILE"
echo "📦 Log archive: $LOG_ARCHIVE"
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

# Function to analyze logs with pattern matching
analyze_logs() {
    local description="$1"
    local log_source="$2"
    local patterns="$3"  # Space-separated patterns to search for
    
    echo "🔍 $description..." | tee -a "$REPORT_FILE"
    echo "Source: $log_source" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    
    local found_issues=false
    
    if [[ -n "$patterns" ]]; then
        for pattern in $patterns; do
            echo "Searching for: $pattern" >> "$REPORT_FILE"
            if eval "$log_source" 2>/dev/null | grep -i "$pattern" >> "$REPORT_FILE" 2>/dev/null; then
                found_issues=true
            fi
        done
    else
        if eval "$log_source" >> "$REPORT_FILE" 2>&1; then
            found_issues=true
        fi
    fi
    
    if $found_issues; then
        echo "✅ Analysis completed - data found" | tee -a "$REPORT_FILE"
    else
        echo "ℹ️  No relevant data found" | tee -a "$REPORT_FILE"
    fi
    echo "" >> "$REPORT_FILE"
}

# Function to collect logs for archive
collect_log() {
    local description="$1"
    local log_command="$2"
    local output_file="$3"
    
    echo "📝 Collecting $description..."
    echo "=== $description ===" > "/tmp/$output_file"
    echo "Generated: $(date)" >> "/tmp/$output_file"
    echo "" >> "/tmp/$output_file"
    
    if eval "$log_command" >> "/tmp/$output_file" 2>&1; then
        echo "✅ $description collected"
    else
        echo "❌ Failed to collect $description" >> "/tmp/$output_file"
    fi
}

# Initialize report
echo "Splashtop Log Analysis Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "System: $(hostname)" >> "$REPORT_FILE"
echo "Analyzer: Kali Linux Splashtop Troubleshooter" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Create temporary directory for log collection
TEMP_LOG_DIR="/tmp/splashtop-logs-$$"
mkdir -p "$TEMP_LOG_DIR"

# System Service Logs
add_section "SYSTEMD SERVICE LOGS"

analyze_logs "Recent service activity" \
    "journalctl -u SRStreamer.service --since='24 hours ago' --no-pager" \
    "error failed exception crashed killed"

analyze_logs "Service startup sequence" \
    "journalctl -u SRStreamer.service --since='7 days ago' --no-pager | grep -E '(Started|Stopped|Failed|Reloading)'" \
    ""

analyze_logs "Service exit codes and signals" \
    "journalctl -u SRStreamer.service --since='7 days ago' --no-pager" \
    "exit-code signal SIGTERM SIGKILL"

# Application Logs
add_section "APPLICATION LOGS"

if [[ -d "/opt/splashtop-streamer/log" ]]; then
    analyze_logs "Application log directory" \
        "ls -la /opt/splashtop-streamer/log/" \
        ""
    
    analyze_logs "Recent application logs" \
        "find /opt/splashtop-streamer/log -name '*.log' -mtime -7 -exec tail -100 {} \;" \
        "error warning exception crash abort"
    
    analyze_logs "Large log files (potential issues)" \
        "find /opt/splashtop-streamer/log -name '*.log' -size +10M -exec ls -lh {} \;" \
        ""
else
    echo "ℹ️  Application log directory not found" | tee -a "$REPORT_FILE"
fi

# System Logs Analysis
add_section "SYSTEM LOGS ANALYSIS"

analyze_logs "Kernel messages related to Splashtop" \
    "dmesg | grep -i -E '(splashtop|srfeature|srstreamer)'" \
    ""

analyze_logs "System crashes and faults" \
    "dmesg" \
    "segfault oops panic killed fault"

analyze_logs "Memory issues" \
    "journalctl --since='24 hours ago' --no-pager" \
    "out.of.memory oom killed"

analyze_logs "Authentication logs" \
    "tail -100 /var/log/auth.log 2>/dev/null || journalctl -u ssh --since='24 hours ago' --no-pager" \
    "splashtop authentication failed denied"

# X11 and Display Logs
add_section "DISPLAY SYSTEM LOGS"

analyze_logs "X11 server logs" \
    "journalctl -u display-manager --since='24 hours ago' --no-pager" \
    "error failed crash"

analyze_logs "Xorg logs" \
    "tail -100 /var/log/Xorg.0.log 2>/dev/null || echo 'Xorg log not found'" \
    "error EE fatal"

analyze_logs "Display manager logs" \
    "journalctl -u gdm -u lightdm -u sddm --since='24 hours ago' --no-pager" \
    "error failed crash splashtop"

# Network and Connection Logs
add_section "NETWORK CONNECTION LOGS"

analyze_logs "Network connection attempts" \
    "journalctl --since='24 hours ago' --no-pager" \
    "connection refused timeout unreachable"

analyze_logs "Firewall logs" \
    "tail -100 /var/log/ufw.log 2>/dev/null || echo 'UFW log not found'" \
    "block deny 443"

analyze_logs "NetworkManager logs" \
    "journalctl -u NetworkManager --since='24 hours ago' --no-pager" \
    "disconnected failed error"

# Performance and Resource Logs
add_section "PERFORMANCE ANALYSIS"

analyze_logs "High CPU usage events" \
    "journalctl --since='24 hours ago' --no-pager" \
    "cpu high.load performance"

analyze_logs "Disk space issues" \
    "journalctl --since='24 hours ago' --no-pager" \
    "no.space disk.full filesystem"

analyze_logs "I/O errors" \
    "dmesg" \
    "i/o.error disk.error read.error write.error"

# Security and Permission Logs
add_section "SECURITY AND PERMISSIONS"

analyze_logs "Permission denied errors" \
    "journalctl --since='24 hours ago' --no-pager" \
    "permission.denied access.denied"

analyze_logs "SELinux denials" \
    "journalctl --since='24 hours ago' --no-pager" \
    "selinux denied avc"

analyze_logs "AppArmor denials" \
    "journalctl --since='24 hours ago' --no-pager" \
    "apparmor denied profile"

# Log Pattern Analysis and Intelligence
add_section "INTELLIGENT LOG ANALYSIS"

{
    echo "🤖 Intelligent Log Pattern Analysis:"
    echo ""
    
    local critical_patterns=()
    local warning_patterns=()
    local info_patterns=()
    
    # Search for critical patterns
    echo "🔍 Scanning for critical issues..."
    
    if journalctl -u SRStreamer.service --since='24 hours ago' --no-pager 2>/dev/null | grep -qi "segmentation.fault\|segfault"; then
        critical_patterns+=("❌ SEGMENTATION FAULT detected - binary corruption or memory access violation")
    fi
    
    if journalctl -u SRStreamer.service --since='24 hours ago' --no-pager 2>/dev/null | grep -qi "killed"; then
        critical_patterns+=("❌ PROCESS KILLED - likely by system OOM killer or administrator")
    fi
    
    if journalctl -u SRStreamer.service --since='24 hours ago' --no-pager 2>/dev/null | grep -qi "permission.denied"; then
        critical_patterns+=("❌ PERMISSION DENIED - service cannot access required resources")
    fi
    
    if journalctl --since='24 hours ago' --no-pager 2>/dev/null | grep -qi "out.of.memory"; then
        critical_patterns+=("❌ OUT OF MEMORY - system running out of available RAM")
    fi
    
    # Search for warning patterns
    if journalctl -u SRStreamer.service --since='24 hours ago' --no-pager 2>/dev/null | grep -qi "failed.*start"; then
        warning_patterns+=("⚠️  SERVICE START FAILURES detected")
    fi
    
    if journalctl -u SRStreamer.service --since='24 hours ago' --no-pager 2>/dev/null | grep -qi "timeout"; then
        warning_patterns+=("⚠️  TIMEOUT ISSUES detected - network or resource delays")
    fi
    
    if journalctl --since='24 hours ago' --no-pager 2>/dev/null | grep -qi "connection.refused"; then
        warning_patterns+=("⚠️  CONNECTION REFUSED - network or firewall blocking")
    fi
    
    # Search for informational patterns
    local restart_count
    restart_count=$(journalctl -u SRStreamer.service --since='7 days ago' --no-pager 2>/dev/null | grep -c "Started\|Stopped" || echo "0")
    if [[ "$restart_count" -gt 10 ]]; then
        info_patterns+=("ℹ️  HIGH RESTART FREQUENCY - service restarted $restart_count times in 7 days")
    fi
    
    # Display findings
    if [[ ${#critical_patterns[@]} -gt 0 ]]; then
        echo "🚨 CRITICAL ISSUES FOUND:"
        for pattern in "${critical_patterns[@]}"; do
            echo "   $pattern"
        done
        echo ""
    fi
    
    if [[ ${#warning_patterns[@]} -gt 0 ]]; then
        echo "⚠️  WARNING PATTERNS DETECTED:"
        for pattern in "${warning_patterns[@]}"; do
            echo "   $pattern"
        done
        echo ""
    fi
    
    if [[ ${#info_patterns[@]} -gt 0 ]]; then
        echo "ℹ️  INFORMATIONAL FINDINGS:"
        for pattern in "${info_patterns[@]}"; do
            echo "   $pattern"
        done
        echo ""
    fi
    
    if [[ ${#critical_patterns[@]} -eq 0 && ${#warning_patterns[@]} -eq 0 ]]; then
        echo "✅ No critical log patterns detected"
        echo ""
    fi
    
    # Provide analysis summary
    echo "📊 Log Analysis Summary:"
    echo "   - Time period: Last 24 hours"
    echo "   - Service logs: $(journalctl -u SRStreamer.service --since='24 hours ago' --no-pager 2>/dev/null | wc -l || echo 'N/A') entries"
    echo "   - System errors: $(journalctl --since='24 hours ago' --priority=err --no-pager 2>/dev/null | wc -l || echo 'N/A') entries"
    echo "   - Application logs: $(find /opt/splashtop-streamer/log -name '*.log' -mtime -1 2>/dev/null | wc -l || echo '0') files"
    
} | tee -a "$REPORT_FILE"

# Collect all logs for archive
echo ""
echo "📦 Collecting logs for archive..."

collect_log "Systemd Service Logs" \
    "journalctl -u SRStreamer.service --since='7 days ago' --no-pager" \
    "systemd-service.log"

collect_log "System Journal Errors" \
    "journalctl --since='7 days ago' --priority=err --no-pager" \
    "system-errors.log"

collect_log "Kernel Messages" \
    "dmesg" \
    "kernel.log"

collect_log "Authentication Logs" \
    "tail -200 /var/log/auth.log 2>/dev/null || journalctl -u ssh --since='7 days ago' --no-pager" \
    "auth.log"

collect_log "Network Manager Logs" \
    "journalctl -u NetworkManager --since='7 days ago' --no-pager" \
    "networkmanager.log"

collect_log "Display Manager Logs" \
    "journalctl -u display-manager --since='7 days ago' --no-pager" \
    "display-manager.log"

if [[ -d "/opt/splashtop-streamer/log" ]]; then
    cp -r /opt/splashtop-streamer/log "$TEMP_LOG_DIR/splashtop-app-logs" 2>/dev/null || echo "Failed to copy app logs"
fi

# Create archive
echo "📦 Creating log archive..."
cd /tmp
tar -czf "$LOG_ARCHIVE" splashtop-logs-$$ 2>/dev/null || echo "Warning: Some logs could not be archived"

# Cleanup
rm -rf "$TEMP_LOG_DIR"

echo ""
echo "========================================"
echo "✅ Log analysis completed!"
echo "========================================"
echo ""
echo "📄 Analysis report: $REPORT_FILE"
echo "📦 Log archive: $LOG_ARCHIVE"
echo "📊 Archive size: $(du -h "$LOG_ARCHIVE" 2>/dev/null | cut -f1 || echo 'Unknown')"
echo ""
echo "🔍 KEY FINDINGS:"
if journalctl -u SRStreamer.service --since='24 hours ago' --no-pager 2>/dev/null | grep -qi "error\|failed\|killed"; then
    echo "   ❌ Service errors detected - review the analysis above"
else
    echo "   ✅ No obvious service errors in recent logs"
fi

if journalctl --since='24 hours ago' --priority=err --no-pager 2>/dev/null | grep -q .; then
    echo "   ❌ System errors present - check system health"
else
    echo "   ✅ No critical system errors in recent logs"
fi

echo ""
echo "💡 Next Steps:"
echo "   1. Review the intelligent analysis results above"
echo "   2. Address any critical issues identified"
echo "   3. Use the log archive for detailed investigation"
echo "   4. Monitor logs in real-time: journalctl -u SRStreamer.service -f"
echo ""
echo "🔧 Related diagnostic tools:"
echo "   ./troubleshooting/crash-analyzer.sh     # If crashes detected"
echo "   ./troubleshooting/system-diagnostic.sh  # For system issues"
echo ""