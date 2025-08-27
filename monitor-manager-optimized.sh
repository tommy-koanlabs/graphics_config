#!/bin/bash

# Optimized Monitor Manager - Fast boot version
# Monitor names and settings
BUILTIN="DP-2"
EXT1="DP-0.1"      # RIGHT monitor (PRIMARY, 144Hz)
EXT2="DP-0.3"      # LEFT monitor (60Hz)

# Quick exit if no display server available (boot-time optimization)
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:0
fi

# Fast check if X server is ready - exit quickly if not
if ! timeout 2 xset q >/dev/null 2>&1; then
    echo "$(date): X server not ready, delaying monitor configuration" >> /var/log/monitor-manager.log
    # Schedule to run later when desktop is ready
    (sleep 10 && /usr/local/bin/monitor-manager.sh) &
    exit 0
fi

# Function to check if a monitor is connected (cached for speed)
is_connected() {
    echo "$XRANDR_OUTPUT" | grep "^$1 connected" > /dev/null
    return $?
}

# Function to set up dual external monitor configuration
setup_dual_external() {
    echo "Setting up dual external monitor configuration..."
    
    # Configure both monitors in a single xrandr command to avoid conflicts
    xrandr --output "$EXT2" --mode 2560x1440 --rate 60 --pos 0x0 \
           --output "$EXT1" --mode 2560x1440 --rate 144 --pos 2560x0 --primary
    
    echo "Dual monitor setup: DP-0.3 (LEFT) at 60Hz, DP-0.1 (RIGHT/PRIMARY) at 144Hz"
}

# Function to set up single external monitor
setup_single_external() {
    local monitor=$1
    echo "Setting up single external monitor: $monitor"
    
    if [ "$monitor" = "$EXT1" ]; then
        # DP-0.1 - set as primary with 144Hz
        xrandr --output "$EXT1" --mode 2560x1440 --rate 144 --primary --pos 0x0
    elif [ "$monitor" = "$EXT2" ]; then
        # DP-0.3 - 60Hz
        xrandr --output "$EXT2" --mode 2560x1440 --rate 60 --primary --pos 0x0
    fi
}

# Function to enable/disable monitors
manage_monitors() {
    # Cache xrandr output for speed (avoid multiple calls)
    XRANDR_OUTPUT=$(xrandr 2>/dev/null)
    
    # Check if either external monitor is connected
    ext1_connected=$(is_connected "$EXT1"; echo $?)
    ext2_connected=$(is_connected "$EXT2"; echo $?)
    
    if [ $ext1_connected -eq 0 ] || [ $ext2_connected -eq 0 ]; then
        # At least one external monitor is connected - disable builtin
        echo "External monitor(s) detected. Disabling builtin display."
        xrandr --output "$BUILTIN" --off
        
        if [ $ext1_connected -eq 0 ] && [ $ext2_connected -eq 0 ]; then
            # Both external monitors connected
            setup_dual_external
        elif [ $ext1_connected -eq 0 ]; then
            # Only DP-0.1 connected
            setup_single_external "$EXT1"
        elif [ $ext2_connected -eq 0 ]; then
            # Only DP-0.3 connected
            setup_single_external "$EXT2"
        fi
        
    else
        # No external monitors connected - enable builtin
        echo "No external monitors detected. Enabling builtin display."
        xrandr --output "$BUILTIN" --auto --primary
    fi
}

# Add user to DISPLAY access (needed for udev-triggered scripts)
if [ -n "$USER" ] && [ "$USER" != "root" ]; then
    xhost +SI:localuser:$USER 2>/dev/null || true
fi

# Run the monitor management
manage_monitors

# Log the action
echo "$(date): Monitor configuration updated" >> /var/log/monitor-manager.log