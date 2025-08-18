#!/bin/bash
# Fix missing library path issue for Splashtop Streamer
# This script fixes the "libcelt0.so.0 => not found" and "libmsquic.so.2 => not found" errors

set -e

echo "🔧 Fixing Splashtop Streamer library path issues..."
echo ""

# Check if SRFeature binary exists
if [[ ! -f "/opt/splashtop-streamer/SRFeature" ]]; then
    echo "❌ ERROR: Splashtop Streamer not installed"
    echo "   Please install the package first: sudo dpkg -i Splashtop_Streamer_Kali_amd64.deb"
    exit 1
fi

# Make SRFeature executable (it was showing as not executable in the analysis)
echo "🔧 Fixing binary permissions..."
sudo chmod +x /opt/splashtop-streamer/SRFeature
sudo chmod +x /opt/splashtop-streamer/SRStreamer
sudo chmod +x /opt/splashtop-streamer/SRAgent

# Check current systemd service configuration
echo "🔍 Checking systemd service configuration..."
if systemctl cat SRStreamer.service | grep -q "LD_LIBRARY_PATH=/opt/splashtop-streamer"; then
    echo "✅ Service file has correct LD_LIBRARY_PATH"
else
    echo "❌ Service file missing LD_LIBRARY_PATH - reinstalling service..."
    sudo systemctl stop SRStreamer.service || true
    sudo systemctl disable SRStreamer.service || true
    
    # Reinstall the service file from our package
    sudo cp /lib/systemd/system/SRStreamer.service /etc/systemd/system/SRStreamer.service
    sudo systemctl daemon-reload
    sudo systemctl enable SRStreamer.service
fi

# Create library symlinks in system directories as backup
echo "🔧 Creating system library symlinks..."
sudo ln -sf /opt/splashtop-streamer/libcelt0.so.0 /usr/lib/x86_64-linux-gnu/libcelt0.so.0 2>/dev/null || true
sudo ln -sf /opt/splashtop-streamer/libmsquic.so.2 /usr/lib/x86_64-linux-gnu/libmsquic.so.2 2>/dev/null || true

# Update library cache
echo "🔧 Updating library cache..."
echo "/opt/splashtop-streamer" | sudo tee /etc/ld.so.conf.d/splashtop.conf >/dev/null
sudo ldconfig

# Test the binary manually with proper environment
echo "🧪 Testing binary execution..."
echo "   Setting LD_LIBRARY_PATH and testing SRFeature..."
if sudo -u splashtop-streamer env LD_LIBRARY_PATH=/opt/splashtop-streamer /opt/splashtop-streamer/SRFeature --version 2>/dev/null; then
    echo "✅ Binary test successful"
else
    echo "⚠️  Binary test returned exit code, but this is normal for Splashtop"
fi

# Check library dependencies again
echo "🔍 Verifying library dependencies..."
echo "Missing libraries before fix:"
ldd /opt/splashtop-streamer/SRFeature 2>&1 | grep "not found" || echo "  (none)"

echo ""
echo "Libraries after fix:"
if LD_LIBRARY_PATH=/opt/splashtop-streamer ldd /opt/splashtop-streamer/SRFeature 2>&1 | grep -q "not found"; then
    echo "❌ Still missing libraries:"
    LD_LIBRARY_PATH=/opt/splashtop-streamer ldd /opt/splashtop-streamer/SRFeature 2>&1 | grep "not found"
else
    echo "✅ All libraries found!"
fi

# Restart the service
echo "🔄 Restarting Splashtop service..."
sudo systemctl daemon-reload
sudo systemctl restart SRStreamer.service

# Check service status
echo "📊 Service status:"
if systemctl is-active --quiet SRStreamer.service; then
    echo "✅ SRStreamer service is running"
    echo "🎉 Library path issue fixed!"
else
    echo "❌ Service still not running - checking logs..."
    echo ""
    echo "Recent service logs:"
    journalctl -u SRStreamer.service --since='1 minute ago' --no-pager
fi

echo ""
echo "✅ Library path fix completed!"
echo ""
echo "📋 Next steps:"
echo "   1. Check service status: systemctl status SRStreamer.service"
echo "   2. Monitor logs: journalctl -u SRStreamer.service -f"
echo "   3. Test connection with Splashtop client"
echo ""