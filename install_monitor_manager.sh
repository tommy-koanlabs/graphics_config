#!/bin/bash

# Monitor Manager Installation Script
# Run with: bash install-monitor-manager.sh

set -e  # Exit on any error

echo "=== Monitor Manager Installation Script ==="
echo "This will set up automatic monitor switching for your triple monitor setup."
echo

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo "Please run this script as your regular user (not sudo)."
   echo "The script will ask for sudo password when needed."
   exit 1
fi

echo "Step 1: Creating monitor management script..."

# Create the main monitor manager script
sudo tee /usr/local/bin/monitor-manager.sh > /dev/null << 'EOF'
#!/bin/bash

# Monitor names from xrandr output
BUILTIN="DP-2"
EXT1="DP-0.1"
EXT2="DP-0.3"

# Function to check if a monitor is connected
is_connected() {
    xrandr | grep "^$1 connected" > /dev/null
    return $?
}

# Function to enable/disable monitors
manage_monitors() {
    # Check if either external monitor is connected
    ext1_connected=$(is_connected "$EXT1"; echo $?)
    ext2_connected=$(is_connected "$EXT2"; echo $?)
    
    if [ $ext1_connected -eq 0 ] || [ $ext2_connected -eq 0 ]; then
        # At least one external monitor is connected - disable builtin
        echo "External monitor(s) detected. Disabling builtin display."
        xrandr --output "$BUILTIN" --off
        
        # Enable connected external monitors
        if [ $ext1_connected -eq 0 ]; then
            xrandr --output "$EXT1" --auto
        fi
        if [ $ext2_connected -eq 0 ]; then
            xrandr --output "$EXT2" --auto
        fi
        
        # If both external monitors are connected, arrange them
        if [ $ext1_connected -eq 0 ] && [ $ext2_connected -eq 0 ]; then
            xrandr --output "$EXT1" --auto --output "$EXT2" --auto --right-of "$EXT1"
        fi
        
    else
        # No external monitors connected - enable builtin
        echo "No external monitors detected. Enabling builtin display."
        xrandr --output "$BUILTIN" --auto
    fi
}

# Set DISPLAY variable if not set (needed for scripts run by udev)
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi

# Run the monitor management
manage_monitors

# Log the action (create directory if it doesn't exist)
mkdir -p ~/scripts/graphics_config/log
echo "$(date): Monitor configuration updated" >> ~/scripts/graphics_config/log/monitor-manager.log
EOF

echo "Step 2: Making script executable..."
sudo chmod +x /usr/local/bin/monitor-manager.sh

echo "Step 3: Creating udev rule for hotplug detection..."
sudo tee /etc/udev/rules.d/99-monitor-hotplug.rules > /dev/null << 'EOF'
# Udev rule for monitor hotplug detection
# This triggers when DisplayPort devices are added or removed
SUBSYSTEM=="drm", ACTION=="change", ENV{HOTPLUG}=="1", RUN+="/usr/local/bin/monitor-manager.sh"
EOF

echo "Step 4: Reloading udev rules..."
sudo udevadm control --reload-rules

echo "Step 5: Creating systemd user service..."
mkdir -p ~/.config/systemd/user

tee ~/.config/systemd/user/monitor-manager.service > /dev/null << 'EOF'
[Unit]
Description=Monitor Manager
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/monitor-manager.sh
Environment=DISPLAY=:0

[Install]
WantedBy=default.target
EOF

echo "Step 6: Enabling and starting the service..."
systemctl --user daemon-reload
systemctl --user enable monitor-manager.service
systemctl --user start monitor-manager.service

echo "Step 7: Creating log directory..."
mkdir -p ~/scripts/graphics_config/log

echo
echo "=== Installation Complete! ==="
echo
echo "Testing the setup..."
/usr/local/bin/monitor-manager.sh

echo
echo "Service status:"
systemctl --user status monitor-manager.service --no-pager

echo
echo "=== Setup Summary ==="
echo "✓ Monitor manager script installed to /usr/local/bin/monitor-manager.sh"
echo "✓ Udev rule installed for automatic hotplug detection"
echo "✓ Systemd service enabled for startup"
echo "✓ Log directory created at ~/scripts/graphics_config/log/"
echo
echo "Your monitors will now automatically switch:"
echo "  • Built-in (DP-2) disables when DP-0.1 OR DP-0.3 is connected"
echo "  • Built-in re-enables when BOTH external monitors are disconnected"
echo
echo "To test: plug/unplug your external monitors"
echo "To check logs: tail -f ~/scripts/graphics_config/log/monitor-manager.log"
echo "To manually run: /usr/local/bin/monitor-manager.sh"
echo
echo "If you need to uninstall, run:"
echo "  sudo rm /usr/local/bin/monitor-manager.sh"
echo "  sudo rm /etc/udev/rules.d/99-monitor-hotplug.rules"
echo "  systemctl --user disable monitor-manager.service"
echo "  rm ~/.config/systemd/user/monitor-manager.service"