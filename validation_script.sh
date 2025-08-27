#!/bin/bash

# System Configuration Validation Script
# Reports the status of all parameters set by the monitor and NVIDIA scripts

# Create timestamped report file
REPORT_FILE="system_validation_report_$(date +%Y%m%d_%H%M%S).txt"

# Function to output to both terminal and file
output() {
    echo "$1" | tee -a "$REPORT_FILE"
}

# Clear any existing report file content
> "$REPORT_FILE"

output "=============================================="
output "System Configuration Validation Report"
output "=============================================="
output "Generated: $(date)"
output ""

# System Information
output "=== System Information ==="
output "Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
output "Kernel: $(uname -r)"
output "Architecture: $(uname -m)"
if command -v nvidia-smi &> /dev/null; then
    output "NVIDIA Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null || echo "Unable to detect")"
else
    output "NVIDIA Driver: Not detected"
fi
output ""

# Files Created/Modified
output "=== Files Status ==="

check_file() {
    local file="$1"
    local description="$2"
    if [[ -f "$file" ]]; then
        if [[ -x "$file" ]]; then
            output "✓ $description: EXISTS (executable)"
        else
            output "✓ $description: EXISTS"
        fi
    else
        output "✗ $description: NOT FOUND"
    fi
}

check_file "/usr/local/bin/monitor-manager.sh" "Monitor manager script"
check_file "/etc/udev/rules.d/99-monitor-hotplug.rules" "Udev monitor hotplug rule"
check_file "$HOME/.config/systemd/user/monitor-manager.service" "Systemd user service file"
check_file "/var/log/monitor-manager.log" "Monitor manager log file"
check_file "/etc/modprobe.d/nvidia-graphics-drivers-kms.conf" "NVIDIA modprobe configuration"
check_file "$HOME/.local/bin/save-kde-display-config.sh" "KDE display config saver"
check_file "$HOME/.config/autostart/monitor-manager.desktop" "Autostart desktop entry"
check_file "$HOME/.local/bin/configure-monitors.sh" "Manual monitor configuration script"

output ""

# System Configuration Status
output "=== System Configuration Status ==="

# GRUB Configuration
output "GRUB Configuration:"
if [[ -f "/etc/default/grub" ]]; then
    local grub_cmdline=$(grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub 2>/dev/null | cut -d'"' -f2)
    output "  GRUB_CMDLINE_LINUX_DEFAULT: \"$grub_cmdline\""
    if echo "$grub_cmdline" | grep -q "acpi.ec_no_wakeup=1"; then
        output "  ✓ acpi.ec_no_wakeup=1: PRESENT"
    else
        output "  ✗ acpi.ec_no_wakeup=1: NOT FOUND"
    fi
else
    output "  ✗ /etc/default/grub: NOT FOUND"
fi

# Check current kernel parameters
output "  Current kernel parameters:"
if grep -q "acpi.ec_no_wakeup=1" /proc/cmdline; then
    output "  ✓ acpi.ec_no_wakeup=1: ACTIVE in current boot"
else
    output "  ✗ acpi.ec_no_wakeup=1: NOT ACTIVE in current boot"
fi

output ""

# NVIDIA Modprobe Configuration
output "NVIDIA Modprobe Configuration:"
if [[ -f "/etc/modprobe.d/nvidia-graphics-drivers-kms.conf" ]]; then
    output "  File contents:"
    while IFS= read -r line; do
        [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]] && output "    $line"
    done < "/etc/modprobe.d/nvidia-graphics-drivers-kms.conf"
    
    if grep -q "NVreg_PreserveVideoMemoryAllocations=1" "/etc/modprobe.d/nvidia-graphics-drivers-kms.conf"; then
        output "  ✓ NVreg_PreserveVideoMemoryAllocations=1: PRESENT"
    else
        output "  ✗ NVreg_PreserveVideoMemoryAllocations=1: NOT FOUND"
    fi
else
    output "  ✗ Configuration file: NOT FOUND"
fi

output ""

# Systemd Services Status
output "Systemd Services Status:"

# User service
output "  User Services:"
if systemctl --user list-unit-files | grep -q "monitor-manager.service"; then
    local user_status=$(systemctl --user is-enabled monitor-manager.service 2>/dev/null)
    local user_active=$(systemctl --user is-active monitor-manager.service 2>/dev/null)
    output "    monitor-manager.service: enabled=$user_status, active=$user_active"
else
    output "    monitor-manager.service: NOT FOUND"
fi

# NVIDIA system services
output "  NVIDIA System Services:"
local nvidia_services=("nvidia-suspend" "nvidia-resume" "nvidia-hibernate")
for service in "${nvidia_services[@]}"; do
    if systemctl list-unit-files | grep -q "${service}.service"; then
        local status=$(systemctl is-enabled "${service}.service" 2>/dev/null || echo "unknown")
        output "    ${service}.service: $status"
    else
        output "    ${service}.service: NOT AVAILABLE"
    fi
done

output ""

# Backup Files Status
output "=== Backup Files Status ==="
output "GRUB backups:"
if ls /etc/default/grub.backup.* &>/dev/null; then
    ls -la /etc/default/grub.backup.* | while read -r line; do
        output "  $line"
    done
else
    output "  No GRUB backup files found"
fi

output "NVIDIA modprobe backups:"
if ls /etc/modprobe.d/nvidia-graphics-drivers-kms.conf.backup.* &>/dev/null; then
    ls -la /etc/modprobe.d/nvidia-graphics-drivers-kms.conf.backup.* | while read -r line; do
        output "  $line"
    done
else
    output "  No NVIDIA modprobe backup files found"
fi

output ""

# Current Monitor Status
output "=== Current Monitor Status ==="
if command -v xrandr &> /dev/null && [[ -n "$DISPLAY" ]]; then
    output "Connected displays:"
    xrandr --listmonitors 2>/dev/null | while read -r line; do
        output "  $line"
    done || output "  Unable to query displays"
    
    output ""
    output "Display configuration:"
    xrandr | grep " connected\| disconnected" | while read -r line; do
        output "  $line"
    done
else
    output "  xrandr not available or DISPLAY not set"
fi

output ""

# Log File Status
output "=== Log File Status ==="
if [[ -f "/var/log/monitor-manager.log" ]]; then
    output "Monitor manager log (last 5 entries):"
    tail -5 /var/log/monitor-manager.log | while read -r line; do
        output "  $line"
    done
else
    output "  Log file not found"
fi

output ""
output "=============================================="
output "Validation Report Complete"
output "=============================================="
output ""
echo "Report saved to: $REPORT_FILE"