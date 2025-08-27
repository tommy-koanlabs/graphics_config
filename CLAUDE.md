# CLAUDE.md

## Hierarchy Context
This is a project-level CLAUDE.md file within the hierarchical instruction system. Parent instructions from `../CLAUDE.md` provide global configuration and behavioral guidelines.

## Project Overview

This is a Linux graphics configuration toolkit containing bash scripts for managing NVIDIA drivers, monitor positioning, and system configurations on Kubuntu/KDE systems. The project focuses on fixing NVIDIA sleep/suspend issues and providing automatic monitor management for multi-monitor setups.

## Architecture

The repository contains several interconnected bash scripts:

- **nvidia_sleep_fix_script.sh**: Fixes NVIDIA driver sleep/suspend issues by configuring kernel parameters and NVIDIA-specific systemd services (currently marked as broken in README)
- **install_monitor_manager.sh**: Sets up infrastructure for automatic monitor switching, creates udev rules and systemd services
- **setup_monitor_positioning.sh**: Enhances monitor management with better positioning and KDE integration
- **validation_script.sh**: System validation tool that reports the status of all configurations applied by other scripts
- **rm_protection_installer.sh**: Installs/uninstalls rm command protection to prevent accidental file deletion

## Key System Components Created

The scripts create and manage:
- `/usr/local/bin/monitor-manager.sh` - Main monitor management script
- `/etc/udev/rules.d/99-monitor-hotplug.rules` - Hardware detection rules
- `~/.config/systemd/user/monitor-manager.service` - User systemd service
- `/var/log/monitor-manager.log` - System logging
- Various KDE/desktop integration files in `~/.local/bin/` and `~/.config/autostart/`

## Project Commands

### Validation and Testing
- `bash validation_script.sh` - Generate comprehensive system status report
- `systemctl --user status monitor-manager.service` - Check service status
- Manual testing: Plug/unplug external monitors to test automatic switching
- Log monitoring: `tail -f /var/log/monitor-manager.log`

### Script Installation
Scripts must be run in specific order:
```bash
bash install_monitor_manager.sh          # Sets up infrastructure  
bash setup_monitor_positioning.sh        # Enhances with better positioning
# bash nvidia_sleep_fix_script.sh        # Currently broken, do not use
```

## Important Notes

### System Modifications
Scripts make significant system changes with automatic backups:
- GRUB kernel parameter modifications (`acpi.ec_no_wakeup=1`)
- NVIDIA driver configuration changes  
- Systemd service creation and management
- Udev rules for hardware detection

### Hardware-Specific Configuration
Monitor names are configured for specific hardware and may require adjustment:
- BUILTIN: DP-2 (laptop display)
- EXT1: DP-0.1 (external monitor 1)  
- EXT2: DP-0.3 (external monitor 2)