#!/bin/bash

# NVIDIA Sleep/Suspend Fix Script for Lenovo LOQ 15ARP9
# Implements both effective and alternative solutions for sleep issues
# Based on community-tested solutions for NVIDIA driver sleep problems

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should NOT be run as root. Run as regular user with sudo access."
        exit 1
    fi
}

# Function to check if NVIDIA drivers are installed
check_nvidia_drivers() {
    if ! command -v nvidia-smi &> /dev/null; then
        print_warning "NVIDIA drivers don't appear to be installed. This script is intended for systems with NVIDIA drivers."
        read -p "Continue anyway? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi
}

# Function to backup files
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        sudo cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        print_status "Backed up $file"
    fi
}

# Function to implement GRUB kernel parameter fix (Most effective solution)
fix_grub_kernel_parameters() {
    print_status "Implementing GRUB kernel parameter fix (Most effective solution)..."
    
    local grub_file="/etc/default/grub"
    backup_file "$grub_file"
    
    # Check if parameter is already present
    if sudo grep -q "acpi.ec_no_wakeup=1" "$grub_file"; then
        print_warning "acpi.ec_no_wakeup=1 parameter already exists in GRUB configuration"
        return 0
    fi
    
    # Add the parameter to GRUB_CMDLINE_LINUX_DEFAULT
    print_status "Adding acpi.ec_no_wakeup=1 to GRUB kernel parameters..."
    
    # Get current GRUB_CMDLINE_LINUX_DEFAULT value
    local current_cmdline=$(sudo grep '^GRUB_CMDLINE_LINUX_DEFAULT=' "$grub_file" | cut -d'"' -f2)
    
    # Add our parameter
    local new_cmdline="$current_cmdline acpi.ec_no_wakeup=1"
    
    # Update the GRUB configuration
    sudo sed -i "s/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT=\"$new_cmdline\"/" "$grub_file"
    
    # Update GRUB
    print_status "Updating GRUB configuration..."
    sudo update-grub
    
    print_success "GRUB kernel parameter fix applied successfully"
}

# Function to implement NVIDIA power management services fix (Alternative approach)
fix_nvidia_power_management() {
    print_status "Implementing NVIDIA power management services fix (Alternative approach)..."
    
    # Create modprobe configuration
    local modprobe_file="/etc/modprobe.d/nvidia-graphics-drivers-kms.conf"
    
    print_status "Configuring NVIDIA power management in modprobe..."
    backup_file "$modprobe_file"
    
    # Check if the option already exists
    if [[ -f "$modprobe_file" ]] && sudo grep -q "NVreg_PreserveVideoMemoryAllocations=1" "$modprobe_file"; then
        print_warning "NVIDIA PreserveVideoMemoryAllocations option already configured"
    else
        # Add or update the NVIDIA options
        echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" | sudo tee -a "$modprobe_file" > /dev/null
        print_success "Added NVreg_PreserveVideoMemoryAllocations=1 to $modprobe_file"
    fi
    
    # Enable NVIDIA suspend/resume services
    print_status "Enabling NVIDIA suspend/resume systemd services..."
    
    local services=("nvidia-suspend" "nvidia-resume" "nvidia-hibernate")
    local enabled_services=()
    local failed_services=()
    
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "${service}.service"; then
            if sudo systemctl enable "${service}.service" 2>/dev/null; then
                enabled_services+=("$service")
            else
                failed_services+=("$service")
            fi
        else
            print_warning "Service ${service}.service not found (may not be needed for your NVIDIA driver version)"
        fi
    done
    
    if [[ ${#enabled_services[@]} -gt 0 ]]; then
        print_success "Enabled services: ${enabled_services[*]}"
    fi
    
    if [[ ${#failed_services[@]} -gt 0 ]]; then
        print_warning "Failed to enable services: ${failed_services[*]}"
        print_warning "These services may not be available with your current NVIDIA driver version"
    fi
}

# Function to show current configuration
show_current_config() {
    print_status "Current configuration summary:"
    echo
    
    # Show GRUB parameters
    echo "GRUB kernel parameters:"
    if [[ -f "/etc/default/grub" ]]; then
        grep "^GRUB_CMDLINE_LINUX_DEFAULT=" /etc/default/grub || echo "  GRUB_CMDLINE_LINUX_DEFAULT not found"
    fi
    echo
    
    # Show modprobe configuration
    echo "NVIDIA modprobe configuration:"
    local modprobe_file="/etc/modprobe.d/nvidia-graphics-drivers-kms.conf"
    if [[ -f "$modprobe_file" ]]; then
        sudo cat "$modprobe_file" | grep -v "^#" | grep -v "^$" || echo "  No active configuration found"
    else
        echo "  Configuration file does not exist"
    fi
    echo
    
    # Show systemd service status
    echo "NVIDIA systemd services status:"
    local services=("nvidia-suspend" "nvidia-resume" "nvidia-hibernate")
    for service in "${services[@]}"; do
        if systemctl list-unit-files | grep -q "${service}.service"; then
            local status=$(systemctl is-enabled "${service}.service" 2>/dev/null || echo "not-found")
            echo "  ${service}: $status"
        else
            echo "  ${service}: not available"
        fi
    done
}

# Function to create system info
create_system_info() {
    print_status "System information:"
    echo "  Kernel: $(uname -r)"
    echo "  Distribution: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Unknown")"
    if command -v nvidia-smi &> /dev/null; then
        echo "  NVIDIA Driver: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits 2>/dev/null || echo "Unable to detect")"
    else
        echo "  NVIDIA Driver: Not detected"
    fi
    echo
}

# Main function
main() {
    echo "=============================================="
    echo "NVIDIA Sleep/Suspend Fix Script"
    echo "For Lenovo LOQ 15ARP9 and similar systems"
    echo "=============================================="
    echo
    
    # Preliminary checks
    check_root
    check_nvidia_drivers
    create_system_info
    
    print_status "This script will implement both recommended solutions:"
    echo "1. Add acpi.ec_no_wakeup=1 to GRUB kernel parameters (Most effective)"
    echo "2. Configure NVIDIA power management services (Alternative approach)"
    echo
    
    read -p "Continue with the fixes? (y/N): " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Operation cancelled by user"
        exit 0
    fi
    
    echo
    print_status "Starting fixes..."
    
    # Apply fixes
    fix_grub_kernel_parameters
    echo
    fix_nvidia_power_management
    
    echo
    print_success "All fixes have been applied!"
    echo
    
    # Show current configuration
    show_current_config
    
    echo
    print_warning "IMPORTANT: A reboot is required for all changes to take effect."
    print_status "After reboot, test suspend/resume functionality to verify the fixes work."
    echo
    print_status "If you continue to experience issues, you may need to:"
    echo "  - Try different NVIDIA driver versions (535, 550, 570)"
    echo "  - Check BIOS settings (disable Fast Boot, set suspend mode to S3 Legacy)"
    echo "  - Consider adding pcie_aspm=off kernel parameter (impacts battery life)"
    echo
    
    read -p "Reboot now? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_status "Rebooting system..."
        sudo reboot
    else
        print_status "Remember to reboot manually to apply changes."
    fi
}

# Run main function
main "$@"