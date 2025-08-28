# Execution Order Recommendation
```bash 
#Run in this order:
#bash nvidia_sleep_fix_script.sh          # Fixes sleep issues BROKEN DONT RUN this is completely broken. Try manually editing the grub
bash install_monitor_manager.sh          # Sets up infrastructure (New version broken! Manually copied over old script, it will introduce delays)
bash setup_monitor_positioning.sh        # Enhances with better positioning
```

# System Changes Made by All Scripts

## Files Created/Modified:

- Create `/usr/local/bin/monitor-manager.sh` with executable permissions (Script 1, then overwritten by Script 3)
- Create `/etc/udev/rules.d/99-monitor-hotplug.rules`
- Create `~/.config/systemd/user/monitor-manager.service`
- Create `/var/log/monitor-manager.log` with 666 permissions
- Create/modify `/etc/modprobe.d/nvidia-graphics-drivers-kms.conf` with "options nvidia NVreg_PreserveVideoMemoryAllocations=1"
- Create `~/.local/bin/save-kde-display-config.sh` with executable permissions
- Create `~/.config/autostart/monitor-manager.desktop`
- Create `~/.local/bin/configure-monitors.sh` with executable permissions

## System Configuration Changes:

- Add "acpi.ec_no_wakeup=1" to GRUB_CMDLINE_LINUX_DEFAULT in `/etc/default/grub`
- Update GRUB configuration
- Reload udev rules via `udevadm control --reload-rules`
- Enable and start systemd user service `monitor-manager.service`
- Enable systemd services `nvidia-suspend.service`, `nvidia-resume.service`, `nvidia-hibernate.service` (if available)
- Reload systemd user daemon

## Backup Files Created:

- Backup `/etc/default/grub` to `/etc/default/grub.backup.[timestamp]`
- Backup `/etc/modprobe.d/nvidia-graphics-drivers-kms.conf` to `/etc/modprobe.d/nvidia-graphics-drivers-kms.conf.backup.[timestamp]` (if file exists)

## UPDATE 8/27/25:
Going to try the fix found at the end of this thread: https://forums.linuxmint.com/viewtopic.php?p=2103191#p2103191
 If that doesnt work will try adding GRUB_CMDLINE_LINUX="quiet splash acpi.ec_no_wakeup=1 pcie_aspm=off" (Default too)

 /usr/bin/nvidia-sleep.sh
 Addding "exit 0" at the top solved the problem.

 ```bash
 #!/bin/bash

exit 0

if [ ! -f /proc/driver/nvidia/suspend ]; then
    exit 0
fi

RUN_DIR="/var/run/nvidia-sleep"
XORG_VT_FILE="${RUN_DIR}"/Xorg.vt_number

PATH="/bin:/usr/bin"

case "$1" in
    suspend|hibernate)
    ...
