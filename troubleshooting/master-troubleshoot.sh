#!/bin/bash
# Master Troubleshooting Script for Splashtop Streamer
# Coordinates all diagnostic tools and provides comprehensive analysis

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
MASTER_REPORT="/tmp/splashtop-master-troubleshoot-$(date +%Y%m%d_%H%M%S).txt"

echo "========================================"
echo "  Splashtop Master Troubleshooter"
echo "========================================"
echo ""
echo "🔧 This comprehensive troubleshooter will run all diagnostic tools"
echo "📝 Master report: $MASTER_REPORT"
echo ""

# Function to run diagnostic script
run_diagnostic() {
    local script_name="$1"
    local description="$2"
    local script_path="$SCRIPT_DIR/$script_name"
    
    echo ""
    echo "🔍 Running $description..."
    echo "========================================"
    
    if [[ -x "$script_path" ]]; then
        if "$script_path"; then
            echo "✅ $description completed successfully"
        else
            echo "⚠️  $description completed with warnings"
        fi
    else
        echo "❌ $script_name not found or not executable"
        echo "   Expected location: $script_path"
        return 1
    fi
    
    echo ""
}

# Initialize master report
echo "Splashtop Master Troubleshooting Report" > "$MASTER_REPORT"
echo "Generated: $(date)" >> "$MASTER_REPORT"
echo "System: $(hostname)" >> "$MASTER_REPORT"
echo "User: $(whoami)" >> "$MASTER_REPORT"
echo "" >> "$MASTER_REPORT"

# Check if we're dealing with a crash
echo "🚨 Checking current Splashtop status..."
if systemctl is-active --quiet SRStreamer.service; then
    SERVICE_STATUS="running"
    echo "✅ SRStreamer service is currently running"
else
    SERVICE_STATUS="not_running"
    echo "❌ SRStreamer service is NOT running"
fi

# Ask user what type of troubleshooting to perform
echo ""
echo "📋 Troubleshooting Options:"
echo "1) Quick Diagnosis (crash analysis + basic checks)"
echo "2) Full System Analysis (all diagnostic tools)"
echo "3) Crash-Focused Analysis (service crashing frequently)"
echo "4) Network-Focused Analysis (connection issues)"
echo "5) Custom Selection"
echo "6) Exit"
echo ""

read -p "Select troubleshooting mode (1-6): " choice

case $choice in
    1)
        echo "🚀 Running Quick Diagnosis..."
        DIAGNOSTICS=("crash-analyzer.sh:Crash Analysis" "splashtop-diagnostic.sh:Service Diagnostic" "dependency-check.sh:Dependency Check")
        ;;
    2)
        echo "🚀 Running Full System Analysis..."
        DIAGNOSTICS=(
            "system-diagnostic.sh:System Diagnostic"
            "dependency-check.sh:Dependency Verification" 
            "splashtop-diagnostic.sh:Splashtop Service Analysis"
            "crash-analyzer.sh:Crash Analysis"
            "network-diagnostic.sh:Network Analysis"
            "log-analyzer.sh:Log Analysis"
        )
        ;;
    3)
        echo "🚀 Running Crash-Focused Analysis..."
        DIAGNOSTICS=("crash-analyzer.sh:Crash Analysis" "log-analyzer.sh:Log Analysis" "system-diagnostic.sh:System Resources")
        ;;
    4)
        echo "🚀 Running Network-Focused Analysis..."
        DIAGNOSTICS=("network-diagnostic.sh:Network Analysis" "splashtop-diagnostic.sh:Service Diagnostic")
        ;;
    5)
        echo "🚀 Custom Selection..."
        echo ""
        echo "Available diagnostic tools:"
        echo "1) System Diagnostic (overall system health)"
        echo "2) Dependency Check (missing packages/libraries)"
        echo "3) Service Diagnostic (Splashtop service analysis)"
        echo "4) Crash Analyzer (crash investigation)"
        echo "5) Network Diagnostic (connectivity issues)"
        echo "6) Log Analyzer (comprehensive log analysis)"
        echo ""
        read -p "Enter numbers to run (e.g., 1,3,4): " selected
        
        DIAGNOSTICS=()
        IFS=',' read -ra SELECTED <<< "$selected"
        for num in "${SELECTED[@]}"; do
            case $num in
                1) DIAGNOSTICS+=("system-diagnostic.sh:System Diagnostic") ;;
                2) DIAGNOSTICS+=("dependency-check.sh:Dependency Check") ;;
                3) DIAGNOSTICS+=("splashtop-diagnostic.sh:Service Diagnostic") ;;
                4) DIAGNOSTICS+=("crash-analyzer.sh:Crash Analysis") ;;
                5) DIAGNOSTICS+=("network-diagnostic.sh:Network Analysis") ;;
                6) DIAGNOSTICS+=("log-analyzer.sh:Log Analysis") ;;
                *) echo "⚠️  Invalid selection: $num" ;;
            esac
        done
        ;;
    6)
        echo "👋 Exiting troubleshooter..."
        exit 0
        ;;
    *)
        echo "❌ Invalid choice, running Quick Diagnosis..."
        DIAGNOSTICS=("crash-analyzer.sh:Crash Analysis" "splashtop-diagnostic.sh:Service Diagnostic")
        ;;
esac

# Ensure scripts are executable
echo "🔧 Making diagnostic scripts executable..."
chmod +x "$SCRIPT_DIR"/*.sh 2>/dev/null || true

# Run selected diagnostics
echo ""
echo "🚀 Starting troubleshooting sequence..."
echo "Time started: $(date)"

successful_runs=0
total_runs=0

for diagnostic in "${DIAGNOSTICS[@]}"; do
    IFS=':' read -r script_name description <<< "$diagnostic"
    total_runs=$((total_runs + 1))
    
    if run_diagnostic "$script_name" "$description"; then
        successful_runs=$((successful_runs + 1))
        echo "Completed: $description" >> "$MASTER_REPORT"
    else
        echo "Failed: $description" >> "$MASTER_REPORT"
    fi
done

# Collect all generated reports
echo ""
echo "📦 Collecting diagnostic reports..."
REPORTS_DIR="/tmp/splashtop-reports-$(date +%Y%m%d_%H%M%S)"
mkdir -p "$REPORTS_DIR"

# Find and collect all recent reports
find /tmp -name "*splashtop*diagnostic*$(date +%Y%m%d)*" -type f -mmin -60 2>/dev/null | while read -r report; do
    if [[ -f "$report" ]]; then
        cp "$report" "$REPORTS_DIR/" 2>/dev/null || true
        echo "Collected: $(basename "$report")"
    fi
done

# Create comprehensive summary
echo ""
echo "📋 Generating comprehensive summary..."

{
    echo ""
    echo "========================================"
    echo "COMPREHENSIVE TROUBLESHOOTING SUMMARY"
    echo "========================================"
    echo ""
    echo "🕐 Analysis completed: $(date)"
    echo "📊 Diagnostics run: $successful_runs/$total_runs successful"
    echo "🖥️  System: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2) $(uname -m)"
    echo "👤 User: $(whoami)"
    echo "📍 Current directory: $(pwd)"
    echo ""
    
    # Service status
    echo "🔧 Current Splashtop Status:"
    if systemctl is-active --quiet SRStreamer.service; then
        echo "   ✅ Service: Running"
        echo "   📊 Memory: $(ps -o pid,ppid,pmem,rss,cmd -C SRFeature 2>/dev/null | tail -1 | awk '{print $4"KB"}' || echo 'N/A')"
    else
        echo "   ❌ Service: Not Running"
        local exit_code
        exit_code=$(systemctl show SRStreamer.service -p ExecMainExitCode --value 2>/dev/null || echo "unknown")
        echo "   🚪 Last exit code: $exit_code"
    fi
    
    # Quick system health
    echo ""
    echo "🩺 System Health Summary:"
    echo "   💾 Memory: $(free -m | grep '^Mem:' | awk '{print $3"/"$2" MB ("int($3/$2*100)"%)"}')"
    echo "   💿 Disk: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5" used)"}')"
    echo "   ⚡ Load: $(uptime | awk '{print $NF}')"
    echo "   🌐 Network: $(ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo "Connected" || echo "Issues detected")"
    
    # Common issues detected
    echo ""
    echo "🔍 Common Issues Analysis:"
    local issues_found=false
    
    # Check for obvious problems
    if ! systemctl is-active --quiet SRStreamer.service; then
        echo "   ❌ Service is not running"
        issues_found=true
    fi
    
    if ! dpkg -l | grep -q splashtop-streamer; then
        echo "   ❌ Package not installed"
        issues_found=true
    fi
    
    if [[ ! -f "/opt/splashtop-streamer/SRFeature" ]]; then
        echo "   ❌ Binary missing"
        issues_found=true
    fi
    
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "   ❌ Network connectivity issues"
        issues_found=true
    fi
    
    # Check for crashes in recent logs
    if journalctl -u SRStreamer.service --since='1 hour ago' --no-pager 2>/dev/null | grep -qi "killed\|segfault\|crashed"; then
        echo "   ❌ Recent crashes detected"
        issues_found=true
    fi
    
    # Check memory pressure
    if free | awk 'NR==2{printf "%.0f", $3*100/$2}' | awk '{if ($1 > 90) print "high"}' | grep -q .; then
        echo "   ⚠️  High memory usage detected"
        issues_found=true
    fi
    
    if ! $issues_found; then
        echo "   ✅ No obvious critical issues detected"
    fi
    
    # Recommendations
    echo ""
    echo "💡 Prioritized Recommendations:"
    
    if ! systemctl is-active --quiet SRStreamer.service; then
        if [[ ! -f "/opt/splashtop-streamer/SRFeature" ]]; then
            echo "   1. 🔧 CRITICAL: Reinstall Splashtop package"
            echo "      sudo dpkg -i Splashtop_Streamer_Kali_amd64.deb"
        else
            echo "   1. 🚀 Try starting the service manually:"
            echo "      sudo systemctl start SRStreamer.service"
            echo "   2. 📋 Check service logs for errors:"
            echo "      journalctl -u SRStreamer.service -f"
        fi
    fi
    
    if ! ping -c 1 8.8.8.8 >/dev/null 2>&1; then
        echo "   3. 🌐 Fix network connectivity issues first"
        echo "      Check network configuration and firewall"
    fi
    
    echo "   4. 📊 Review detailed diagnostic reports in:"
    echo "      $REPORTS_DIR"
    
    # Next steps
    echo ""
    echo "🚀 Suggested Next Steps:"
    if systemctl is-active --quiet SRStreamer.service; then
        echo "   ✅ Service is running - test remote connection"
        echo "   📱 Try connecting with Splashtop client"
        echo "   📊 Monitor performance: htop"
    else
        echo "   1. Address critical issues identified above"
        echo "   2. Restart service: sudo systemctl restart SRStreamer.service"
        echo "   3. Monitor logs: journalctl -u SRStreamer.service -f"
        echo "   4. Test connection after fixes"
    fi
    
    # Support information
    echo ""
    echo "📞 Support Information:"
    echo "   📄 Master report: $MASTER_REPORT"
    echo "   📁 All reports: $REPORTS_DIR"
    echo "   🏷️  Package version: $(dpkg -l | grep splashtop-streamer | awk '{print $3}' || echo 'Not installed')"
    echo "   🕐 Report timestamp: $(date)"
    
} | tee -a "$MASTER_REPORT"

# Create archive with all reports
ARCHIVE_FILE="/tmp/splashtop-troubleshoot-$(date +%Y%m%d_%H%M%S).tar.gz"
if [[ -d "$REPORTS_DIR" ]]; then
    tar -czf "$ARCHIVE_FILE" -C "$REPORTS_DIR" . 2>/dev/null || echo "Warning: Could not create archive"
    echo ""
    echo "📦 Complete troubleshooting archive: $ARCHIVE_FILE"
fi

echo ""
echo "========================================"
echo "✅ Master troubleshooting completed!"
echo "========================================"
echo ""
echo "📊 Results Summary:"
echo "   📋 Diagnostics completed: $successful_runs/$total_runs"
echo "   📄 Master report: $MASTER_REPORT"
echo "   📁 Detailed reports: $REPORTS_DIR"
echo "   📦 Archive: ${ARCHIVE_FILE}"
echo ""

# Display immediate action items
if ! systemctl is-active --quiet SRStreamer.service; then
    echo "🚨 IMMEDIATE ACTION REQUIRED:"
    echo "   The Splashtop service is not running!"
    echo ""
    echo "   Quick fix attempts:"
    echo "   1. sudo systemctl start SRStreamer.service"
    echo "   2. sudo systemctl restart SRStreamer.service"
    echo "   3. Check logs: journalctl -u SRStreamer.service"
    echo ""
else
    echo "✅ SERVICE STATUS: Running normally"
    echo "💡 If you're still experiencing issues:"
    echo "   - Check the detailed reports above"
    echo "   - Test remote connection"
    echo "   - Monitor system resources"
fi

echo ""
echo "🔧 Re-run specific diagnostics:"
echo "   ./troubleshooting/crash-analyzer.sh     # For crashes"
echo "   ./troubleshooting/network-diagnostic.sh # For network issues" 
echo "   ./troubleshooting/log-analyzer.sh       # For detailed logs"
echo ""