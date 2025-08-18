#!/bin/bash
# Dependency Verification Script for Splashtop Streamer
# Comprehensive dependency checking and resolution

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
REPORT_FILE="/tmp/splashtop-dependency-check-$(date +%Y%m%d_%H%M%S).txt"

echo "========================================"
echo "  Splashtop Dependency Verification"
echo "========================================"
echo ""
echo "🔍 This script will verify all Splashtop dependencies and suggest fixes"
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

# Function to check dependency
check_dependency() {
    local dep_name="$1"
    local check_command="$2"
    local install_command="$3"
    local description="$4"
    
    echo -n "🔍 Checking $dep_name... " | tee -a "$REPORT_FILE"
    
    if eval "$check_command" >/dev/null 2>&1; then
        echo "✅ OK" | tee -a "$REPORT_FILE"
        echo "   $description: Available" >> "$REPORT_FILE"
        return 0
    else
        echo "❌ MISSING" | tee -a "$REPORT_FILE"
        echo "   $description: Not found" >> "$REPORT_FILE"
        echo "   Install with: $install_command" >> "$REPORT_FILE"
        return 1
    fi
}

# Function to check package dependency
check_package() {
    local package="$1"
    local description="$2"
    local alternatives="$3"  # Optional alternative packages
    
    echo -n "🔍 Package $package... " | tee -a "$REPORT_FILE"
    
    if dpkg -l | grep -q "^ii.*$package"; then
        local version
        version=$(dpkg -l | grep "^ii.*$package" | awk '{print $3}' | head -1)
        echo "✅ OK ($version)" | tee -a "$REPORT_FILE"
        echo "   $description: Installed" >> "$REPORT_FILE"
        return 0
    else
        echo "❌ MISSING" | tee -a "$REPORT_FILE"
        echo "   $description: Not installed" >> "$REPORT_FILE"
        if [[ -n "$alternatives" ]]; then
            echo "   Alternatives: $alternatives" >> "$REPORT_FILE"
        fi
        echo "   Install with: sudo apt install $package" >> "$REPORT_FILE"
        return 1
    fi
}

# Function to check library dependency
check_library() {
    local lib_name="$1"
    local binary_path="$2"
    
    echo -n "🔍 Library $lib_name... " | tee -a "$REPORT_FILE"
    
    if [[ -f "$binary_path" ]] && ldd "$binary_path" 2>/dev/null | grep -q "$lib_name"; then
        if ldd "$binary_path" 2>/dev/null | grep "$lib_name" | grep -q "not found"; then
            echo "❌ NOT FOUND" | tee -a "$REPORT_FILE"
            echo "   Library $lib_name required by $binary_path but not found" >> "$REPORT_FILE"
            return 1
        else
            echo "✅ OK" | tee -a "$REPORT_FILE"
            local lib_path
            lib_path=$(ldd "$binary_path" 2>/dev/null | grep "$lib_name" | awk '{print $3}' | head -1)
            echo "   Library path: ${lib_path:-'embedded'}" >> "$REPORT_FILE"
            return 0
        fi
    else
        echo "⚠️  SKIP" | tee -a "$REPORT_FILE"
        echo "   Binary $binary_path not found, cannot check $lib_name" >> "$REPORT_FILE"
        return 1
    fi
}

# Initialize report
echo "Splashtop Dependency Verification Report" > "$REPORT_FILE"
echo "Generated: $(date)" >> "$REPORT_FILE"
echo "System: $(uname -a)" >> "$REPORT_FILE"
echo "Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# System Package Dependencies
add_section "SYSTEM PACKAGES"

missing_packages=()

if ! check_package "libatomic1" "Atomic operations library"; then
    missing_packages+=("libatomic1")
fi

if ! check_package "libc6" "GNU C Library"; then
    missing_packages+=("libc6")
fi

if ! check_package "libcairo2" "Cairo graphics library"; then
    missing_packages+=("libcairo2")
fi

if ! check_package "libdbus-1-3" "D-Bus system message bus library"; then
    missing_packages+=("libdbus-1-3")
fi

# FUSE with alternatives
if ! check_package "libfuse2" "FUSE library" "fuse fuse3"; then
    if ! check_package "fuse" "FUSE filesystem" "libfuse2 fuse3"; then
        if ! check_package "fuse3" "FUSE3 filesystem" "fuse libfuse2"; then
            missing_packages+=("fuse")
        fi
    fi
fi

# GCC library with alternatives
if ! check_package "libgcc-s1" "GCC support library" "libgcc1"; then
    if ! check_package "libgcc1" "GCC support library (legacy)" "libgcc-s1"; then
        missing_packages+=("libgcc-s1")
    fi
fi

# Graphics and UI Dependencies
add_section "GRAPHICS AND UI LIBRARIES"

if ! check_package "libgdk-pixbuf-2.0-0" "GDK Pixbuf library" "libgdk-pixbuf2.0-0"; then
    check_package "libgdk-pixbuf2.0-0" "GDK Pixbuf library (alt)" "libgdk-pixbuf-2.0-0"
fi

check_package "libglib2.0-0" "GLib library"
check_package "libgtk-3-0" "GTK+ 3.0 library"
check_package "libnotify4" "Desktop notifications library"

# Audio and Media Dependencies
add_section "AUDIO AND MEDIA"

check_package "libopus0" "Opus audio codec"
check_package "libpulse0" "PulseAudio client library"
check_package "pulseaudio-utils" "PulseAudio utilities"

# Network and Proxy Dependencies
add_section "NETWORK LIBRARIES"

if ! check_package "libproxy1v5" "Proxy configuration library" "libproxy1-plugin-gsettings"; then
    check_package "libproxy1-plugin-gsettings" "Proxy plugin for GSettings" "libproxy1v5"
fi

if ! check_package "libsoup2.4-1" "SOUP HTTP library" "libsoup-3.0-0"; then
    check_package "libsoup-3.0-0" "SOUP HTTP library v3" "libsoup2.4-1"
fi

# WebKit Dependencies
add_section "WEBKIT DEPENDENCIES"

webkit_found=false
if check_package "libwebkit2gtk-4.1-0" "WebKit GTK 4.1" "libwebkit2gtk-4.0-37 libwebkit2gtk-4.0-dev"; then
    webkit_found=true
elif check_package "libwebkit2gtk-4.0-37" "WebKit GTK 4.0" "libwebkit2gtk-4.1-0 libwebkit2gtk-4.0-dev"; then
    webkit_found=true
elif check_package "libwebkit2gtk-4.0-dev" "WebKit GTK dev" "libwebkit2gtk-4.1-0 libwebkit2gtk-4.0-37"; then
    webkit_found=true
fi

if ! $webkit_found; then
    missing_packages+=("libwebkit2gtk-4.1-0")
fi

# System Utilities
add_section "SYSTEM UTILITIES"

check_package "adduser" "User management utilities"
check_package "curl" "HTTP client"
check_package "bash-completion" "Bash completion system"
check_package "lshw" "Hardware information tool"
check_package "util-linux" "System utilities"
check_package "zip" "Archive utility"

# X11 and Input Dependencies
add_section "X11 AND INPUT SYSTEM"

check_package "x11-xserver-utils" "X11 server utilities"
check_package "xinput" "X11 input configuration"
check_package "libxcb-keysyms1" "XCB key symbols"
check_package "libxcb-randr0" "XCB RandR extension"
check_package "libxcb-screensaver0" "XCB screensaver extension"
check_package "libxcb1" "X11 C Bindings library"

# PolicyKit Dependencies (with alternatives)
add_section "POLICY KIT AUTHENTICATION"

policykit_found=false
if check_package "polkitd" "PolicyKit daemon (current)" "policykit-1 pkexec"; then
    policykit_found=true
elif check_package "policykit-1" "PolicyKit system (legacy)" "polkitd pkexec"; then
    policykit_found=true
elif check_dependency "pkexec" "which pkexec" "sudo apt install polkitd" "PolicyKit execution utility"; then
    policykit_found=true
fi

if ! $policykit_found; then
    missing_packages+=("polkitd")
fi

# Binary Dependencies Analysis
add_section "BINARY LIBRARY ANALYSIS"

SPLASHTOP_BINARY="/opt/splashtop-streamer/SRFeature"

if [[ -f "$SPLASHTOP_BINARY" ]]; then
    echo "🔍 Analyzing binary dependencies for: $SPLASHTOP_BINARY" | tee -a "$REPORT_FILE"
    echo "Binary info:" >> "$REPORT_FILE"
    file "$SPLASHTOP_BINARY" >> "$REPORT_FILE" 2>&1
    echo "" >> "$REPORT_FILE"
    
    echo "Library dependencies:" >> "$REPORT_FILE"
    ldd "$SPLASHTOP_BINARY" >> "$REPORT_FILE" 2>&1 || echo "Failed to analyze dependencies" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Check for missing libraries
    missing_libs=()
    if ldd "$SPLASHTOP_BINARY" 2>/dev/null | grep -q "not found"; then
        echo "❌ Missing libraries detected:" | tee -a "$REPORT_FILE"
        while IFS= read -r line; do
            echo "   $line" | tee -a "$REPORT_FILE"
            lib_name=$(echo "$line" | awk '{print $1}')
            missing_libs+=("$lib_name")
        done < <(ldd "$SPLASHTOP_BINARY" 2>/dev/null | grep "not found")
    else
        echo "✅ All binary libraries found" | tee -a "$REPORT_FILE"
    fi
else
    echo "❌ Splashtop binary not found: $SPLASHTOP_BINARY" | tee -a "$REPORT_FILE"
fi

# Development Dependencies (optional)
add_section "DEVELOPMENT TOOLS (OPTIONAL)"

check_dependency "gdb" "which gdb" "sudo apt install gdb" "GNU Debugger (for crash analysis)"
check_dependency "strace" "which strace" "sudo apt install strace" "System call tracer"
check_dependency "valgrind" "which valgrind" "sudo apt install valgrind" "Memory debugger"

# Generate Dependency Resolution Plan
add_section "DEPENDENCY RESOLUTION PLAN"

{
    echo "🔧 Dependency Analysis Summary:"
    echo ""
    
    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        echo "✅ All critical dependencies are satisfied!"
        echo ""
        echo "🎉 Your system appears to have all required packages for Splashtop Streamer."
    else
        echo "❌ Missing Dependencies Found: ${#missing_packages[@]}"
        echo ""
        echo "📋 Missing Packages:"
        for pkg in "${missing_packages[@]}"; do
            echo "   - $pkg"
        done
        echo ""
        echo "🚀 Quick Fix Command:"
        echo "   sudo apt update"
        echo "   sudo apt install ${missing_packages[*]}"
        echo ""
        echo "🔧 Alternative Fix (with error handling):"
        echo "   sudo apt update"
        for pkg in "${missing_packages[@]}"; do
            echo "   sudo apt install -y $pkg || echo 'Failed to install $pkg'"
        done
    fi
    
    # Additional recommendations
    echo ""
    echo "💡 Additional Recommendations:"
    
    # Check if running automated fix script
    if [[ -x "$SCRIPT_DIR/../fix-dependencies.sh" ]]; then
        echo "   1. Run the automated dependency fixer:"
        echo "      $SCRIPT_DIR/../fix-dependencies.sh"
    fi
    
    echo "   2. Update package lists before installing:"
    echo "      sudo apt update && sudo apt upgrade"
    
    echo "   3. Clean package cache if issues persist:"
    echo "      sudo apt autoclean && sudo apt autoremove"
    
    if [[ ${#missing_libs[@]} -gt 0 ]]; then
        echo "   4. Missing binary libraries detected - consider reinstalling package"
        echo "   5. Check for broken package installations: dpkg --audit"
    fi
    
    # System-specific recommendations
    echo ""
    echo "🐧 Kali Linux Specific:"
    echo "   - Ensure Kali repositories are properly configured"
    echo "   - Some packages may have different names in Kali vs Debian"
    echo "   - Consider using 'apt search' to find alternative package names"
    
    echo ""
    echo "📊 System Summary:"
    echo "   - Distribution: $(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)"
    echo "   - Architecture: $(dpkg --print-architecture)"
    echo "   - Available packages: $(apt list 2>/dev/null | wc -l)"
    echo "   - Installed packages: $(dpkg -l | grep '^ii' | wc -l)"
    
} | tee -a "$REPORT_FILE"

# Create dependency fix script
DEPENDENCY_SCRIPT="/tmp/fix-splashtop-dependencies-$(date +%Y%m%d_%H%M%S).sh"
cat > "$DEPENDENCY_SCRIPT" << EOF
#!/bin/bash
# Auto-generated Splashtop dependency fix script
# Generated: $(date)

set -e

echo "🔧 Fixing Splashtop dependencies..."

# Update package lists
echo "📦 Updating package lists..."
sudo apt update

# Install missing packages
echo "📦 Installing missing dependencies..."
EOF

for pkg in "${missing_packages[@]}"; do
    echo "sudo apt install -y $pkg || echo '❌ Failed to install $pkg'" >> "$DEPENDENCY_SCRIPT"
done

cat >> "$DEPENDENCY_SCRIPT" << EOF

# Verify installation
echo "🔍 Verifying installation..."
if dpkg -l | grep -q splashtop-streamer; then
    echo "✅ Splashtop package is installed"
else
    echo "⚠️  Splashtop package needs to be installed"
fi

echo "✅ Dependency fix completed!"
echo "💡 Next step: Install or reinstall Splashtop package"
EOF

chmod +x "$DEPENDENCY_SCRIPT"

echo ""
echo "========================================"
echo "✅ Dependency verification completed!"
echo "========================================"
echo ""
echo "📄 Report location: $REPORT_FILE"
echo "🔧 Auto-fix script: $DEPENDENCY_SCRIPT"
echo ""

# Summary
if [[ ${#missing_packages[@]} -eq 0 ]]; then
    echo "🎉 ALL DEPENDENCIES SATISFIED!"
    echo "   Your system has all required packages for Splashtop Streamer."
else
    echo "❌ MISSING DEPENDENCIES: ${#missing_packages[@]}"
    echo "   Run the auto-fix script: $DEPENDENCY_SCRIPT"
    echo "   Or install manually: sudo apt install ${missing_packages[*]}"
fi

echo ""
echo "💡 Next steps:"
echo "   1. Fix any missing dependencies shown above"
echo "   2. Reinstall Splashtop package if binary libraries are missing"
echo "   3. Run service diagnostic: ./troubleshooting/splashtop-diagnostic.sh"
echo ""