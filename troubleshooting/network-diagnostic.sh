#!/bin/bash
# Network Diagnostic Script for Splashtop Streamer
# Analyzes network connectivity, firewall, and port configuration

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPORT_FILE="/tmp/splashtop-network-diagnostic-$(date +%Y%m%d_%H%M%S).txt"

echo "========================================"
echo "  Splashtop Network Diagnostic Tool"
echo "========================================"
echo ""
echo "🌐 This script will analyze network connectivity and configuration for Splashtop"
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

# Function for network tests
test_network() {
    local description="$1"
    local command="$2"
    
    echo -n "🔍 $description... " | tee -a "$REPORT_FILE"
    
    if eval "$command" >/dev/null 2>&1; then
        echo "✅ OK" | tee -a "$REPORT_FILE"
        return 0
    else
        echo "❌ FAILED" | tee -a "$REPORT_FILE"
        return 1
    fi
}

# Function for detailed analysis
analyze_network() {
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
echo "Splashtop Network Diagnostic Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "System: $(hostname)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Basic Network Configuration
add_section "NETWORK CONFIGURATION"

analyze_network "Network interfaces" "ip addr show"
analyze_network "Routing table" "ip route show"
analyze_network "Network statistics" "ip -s link show"
analyze_network "ARP table" "arp -a || ip neigh show"

# Connectivity Tests
add_section "CONNECTIVITY TESTS"

test_network "Loopback connectivity" "ping -c 2 127.0.0.1"
test_network "Local network connectivity" "ping -c 2 \$(ip route | grep default | awk '{print \$3}' | head -1)"
test_network "Internet connectivity (Google DNS)" "ping -c 3 8.8.8.8"
test_network "DNS resolution" "nslookup google.com"
test_network "HTTPS connectivity" "curl -s --connect-timeout 5 https://www.google.com >/dev/null"

# Splashtop Specific Network Analysis
add_section "SPLASHTOP NETWORK ANALYSIS"

analyze_network "Listening ports" "netstat -tlnp | grep -E '(splashtop|SRFeature|SRStreamer)' || echo 'No Splashtop ports found'"
analyze_network "All listening ports" "ss -tlnp"
analyze_network "Active connections" "netstat -an | grep ESTABLISHED"

# Check common Splashtop ports
SPLASHTOP_PORTS=(443 6783 443)
for port in "${SPLASHTOP_PORTS[@]}"; do
    analyze_network "Port $port availability" "netstat -tln | grep :$port || echo 'Port $port not in use'"
done

# Firewall Analysis
add_section "FIREWALL ANALYSIS"

analyze_network "UFW status" "ufw status verbose 2>/dev/null || echo 'UFW not available'"
analyze_network "UFW rules" "ufw status numbered 2>/dev/null || echo 'UFW not configured'"

analyze_network "Iptables INPUT rules" "iptables -L INPUT -n --line-numbers"
analyze_network "Iptables OUTPUT rules" "iptables -L OUTPUT -n --line-numbers"
analyze_network "Iptables FORWARD rules" "iptables -L FORWARD -n --line-numbers"
analyze_network "NAT table" "iptables -t nat -L -n"

# Network Manager Analysis
add_section "NETWORK MANAGER ANALYSIS"

analyze_network "NetworkManager status" "systemctl status NetworkManager --no-pager"
analyze_network "Network connections" "nmcli connection show"
analyze_network "WiFi status" "nmcli radio wifi"
analyze_network "VPN connections" "nmcli connection show --active | grep vpn || echo 'No active VPN connections'"

# DNS Analysis
add_section "DNS CONFIGURATION"

analyze_network "DNS configuration" "cat /etc/resolv.conf"
analyze_network "DNS cache status" "systemctl status systemd-resolved --no-pager 2>/dev/null || echo 'systemd-resolved not available'"
analyze_network "DNS lookup test" "dig google.com +short || echo 'dig not available'"

# Network Security Analysis
add_section "NETWORK SECURITY"

analyze_network "Network security status" "ss -tulpn | head -20"
analyze_network "Open ports summary" "nmap -sT -O localhost 2>/dev/null | head -20 || echo 'nmap not available'"

# Proxy and Network Policies
add_section "PROXY CONFIGURATION"

analyze_network "HTTP proxy settings" "env | grep -i proxy || echo 'No proxy environment variables'"
analyze_network "System proxy configuration" "cat /etc/environment | grep -i proxy || echo 'No system proxy configuration'"

# Performance Analysis
add_section "NETWORK PERFORMANCE"

analyze_network "Network interface statistics" "cat /proc/net/dev"
analyze_network "Network buffer statistics" "ss -m"

# Test specific network requirements for Splashtop
analyze_network "Bandwidth test (simple)" "curl -s --max-time 10 http://www.google.com/robots.txt | wc -c || echo 'Bandwidth test failed'"

# Network Troubleshooting
add_section "NETWORK TROUBLESHOOTING"

{
    echo "🔍 Network Issue Analysis:"
    echo ""
    
    local network_issues=()
    local recommendations=()
    
    # Test basic connectivity
    if ! ping -c 1 127.0.0.1 >/dev/null 2>&1; then
        network_issues+=("❌ CRITICAL: Loopback interface not working")
        recommendations+=("Check network stack: sudo systemctl restart NetworkManager")
    fi
    
    # Test gateway connectivity
    local gateway
    gateway=$(ip route | grep default | awk '{print $3}' | head -1)
    if [[ -n "$gateway" ]] && ! ping -c 2 "$gateway" >/dev/null 2>&1; then
        network_issues+=("❌ CRITICAL: Cannot reach network gateway ($gateway)")
        recommendations+=("Check network cable/WiFi connection")
        recommendations+=("Restart network interface: sudo ip link set dev eth0 down && sudo ip link set dev eth0 up")
    fi
    
    # Test internet connectivity
    if ! ping -c 2 8.8.8.8 >/dev/null 2>&1; then
        network_issues+=("❌ ERROR: No internet connectivity")
        recommendations+=("Check ISP connection")
        recommendations+=("Verify firewall is not blocking outbound traffic")
    fi
    
    # Test DNS resolution
    if ! nslookup google.com >/dev/null 2>&1; then
        network_issues+=("❌ ERROR: DNS resolution not working")
        recommendations+=("Check DNS servers in /etc/resolv.conf")
        recommendations+=("Try alternative DNS: echo 'nameserver 8.8.8.8' | sudo tee /etc/resolv.conf")
    fi
    
    # Check firewall blocking
    if ufw status 2>/dev/null | grep -q "Status: active"; then
        if ! ufw status | grep -q "443"; then
            network_issues+=("⚠️  WARNING: UFW active but port 443 not explicitly allowed")
            recommendations+=("Allow HTTPS: sudo ufw allow 443")
        fi
    fi
    
    # Check for VPN interference
    if nmcli connection show --active | grep -q vpn; then
        network_issues+=("⚠️  INFO: VPN connection active (may affect Splashtop routing)")
        recommendations+=("Test without VPN if issues persist")
    fi
    
    # Check for proxy configuration
    if env | grep -qi proxy; then
        network_issues+=("⚠️  INFO: Proxy configuration detected")
        recommendations+=("Verify proxy settings don't block Splashtop traffic")
    fi
    
    # Display results
    if [[ ${#network_issues[@]} -eq 0 ]]; then
        echo "✅ No major network issues detected"
        echo ""
        echo "🌐 Network appears to be functioning normally"
        echo "   - Connectivity: OK"
        echo "   - DNS: OK" 
        echo "   - Internet access: OK"
    else
        echo "🚨 Network Issues Found:"
        for issue in "${network_issues[@]}"; do
            echo "   $issue"
        done
    fi
    
    echo ""
    echo "📋 Recommended Actions:"
    if [[ ${#recommendations[@]} -eq 0 ]]; then
        recommendations+=("Monitor network performance during Splashtop usage")
        recommendations+=("Check router/firewall logs for blocked connections")
        recommendations+=("Verify no other remote desktop software is conflicting")
    fi
    
    for i in "${!recommendations[@]}"; do
        echo "   $((i+1)). ${recommendations[i]}"
    done
    
    echo ""
    echo "🔧 Advanced Network Debugging:"
    echo "   - Capture traffic: sudo tcpdump -i any -w /tmp/splashtop.pcap port 443"
    echo "   - Monitor connections: watch 'ss -tulpn | grep SRFeature'"
    echo "   - Test with specific IP: telnet [splashtop-server-ip] 443"
    echo "   - Check MTU size: ping -M do -s 1472 8.8.8.8"
    echo ""
    echo "🌐 Splashtop Network Requirements:"
    echo "   - Outbound HTTPS (443) access required"
    echo "   - No blocking of splashtop.com domain"
    echo "   - Stable internet connection (>1Mbps recommended)"
    echo "   - Low latency preferred (<100ms)"
    
    # Network performance summary
    local ip_addr
    ip_addr=$(hostname -I | awk '{print $1}')
    echo ""
    echo "📊 Network Summary:"
    echo "   - Primary IP: ${ip_addr:-'Not detected'}"
    echo "   - Gateway: ${gateway:-'Not detected'}"
    echo "   - DNS: $(grep nameserver /etc/resolv.conf | head -1 | awk '{print $2}' || echo 'Not configured')"
    echo "   - Firewall: $(ufw status 2>/dev/null | head -1 | cut -d: -f2 || echo 'Unknown')"
    
} | tee -a "$REPORT_FILE"

echo ""
echo "========================================"
echo "✅ Network diagnostic completed!"
echo "========================================"
echo ""
echo "📄 Report location: $REPORT_FILE"
echo "📊 Report size: $(du -h "$REPORT_FILE" | cut -f1)"
echo ""
echo "🌐 NETWORK STATUS SUMMARY:"
echo "   - Connectivity: $(ping -c 1 8.8.8.8 >/dev/null 2>&1 && echo '✅ OK' || echo '❌ FAILED')"
echo "   - DNS: $(nslookup google.com >/dev/null 2>&1 && echo '✅ OK' || echo '❌ FAILED')"
echo "   - Firewall: $(ufw status 2>/dev/null | head -1 | cut -d: -f2 || echo 'Unknown')"
echo ""
echo "💡 If network issues are found:"
echo "   1. Follow the recommended actions above"
echo "   2. Test Splashtop after network fixes"
echo "   3. Monitor network during Splashtop connection attempts"
echo ""