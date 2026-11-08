#!/usr/bin/bash

# MIT License
# Copyright (c) 2026 allmun

set -e

# #########################################################################################
# Check conditions for running this cripts
# #########################################################################################

# Check if script is executed from the expected folder
[[ "$PWD" == */aida/install ]]  || {
    echo "Error: This script mist be executed from the 'aida/install'folder"
    exit 1
}

# Ensure correct exection order of installation scripts
if [[ ! -f "/var/aida/.done/1st-prepare-and-setup.sh" ]]; then
    echo "Error: First run 'sudo bash 1st-prepare-and-setup.sh' first to ensure correct setup before runing this script";
    exit 1
fi

# Prevent running this script muliple times
if [ -f "/var/aida/.done/$0" ]; then
    echo "Error: All installation scripts executed"
    echo "To update installation, run 'sudo update-installation.sh'";
    exit 1
fi

# #########################################################################################
# Temporarily mount @snapshots on /.snapshot
# #########################################################################################

# Get subvoume name, device name and uuid of mounted root partition
mounted_root_subvol_name=$(findmnt / | tail -n 1 | awk -F'[][]' '{print $2}')
mounted_root_device_name=$(mount | grep " / " | awk -F' ' '{print $1}')
mounted_root_device_uuid=$(blkid "$mounted_root_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')

# mount /.snapshots
mount -t btrfs -o subvol=@snapshots,defaults,noatime,compress=lzo "$mounted_root_device_name" "$snapshot_dir"

# #########################################################################################
# Create first snapshots and update according to declarative configuration
# #########################################################################################

# Create snapshot
echo ""
echo "Info: Creating first snapshot ..."
unmount_aida_mnt

# Update snapshot to declared configuration
echo ""
echo "Info: Updating snapshot to declared configuration ..."
update_root_subvol

# #########################################################################################
# Install initcpio hooks for (re)mounting root /, ./snapshots,and /etc overlay
# #########################################################################################

# Copy aida-mounts to etc/initcpio folders
echo "Info: Copying aida-remounts hooks to $aida_mnt_diretc/initcpio folders ..."
cp -v ../res/aida-mounts-install "$aida_mnt_dir/etc/initcpio/install/aida-mounts"
cp -v ../res/aida-mounts-hooks "$aida_mnt_dir/etc/initcpio/hooks/aida-mounts"

# Add aida-mounts hooks to mkinitcpio configuration
echo "Info: Adding aida-remounts to mkinitcpio configuration ..."
echo "HOOKS+=(aida-mounts)" >> "$aida_mnt_dir/etc/mkinitcpio.conf"

# Update initramfs to include aida-hooks
echo "Info: Running mkinitcpio to genarate new initramfs that includes aida-mounts ..."
run_chroot_shell_commands "mkinitcpio -P"

# Remove mount point defintion for root folder in etc/fstab:
echo "Info: removing root partition / from $aida_mnt_dri/etc/fstab ..."
sed -i "s|^UUID=<$mounted_root_device_uuid> / |# &|" "$aida_mnt_dir/etc/fstab"

# #########################################################################################
# Switch to new snapshot
# # #########################################################################################

# Update grub menu to point at new snapshot
echo ""
echo "Info: Updating grub menu to point to snapshot"
switch_to_new_snapshot

# #########################################################################################
# Finish and exit
# # #########################################################################################

# Mark this script as executed (it is premature but cannot be done after migration and before reboot)
mkdir -p /var/aida/.done
touch "/var/aida/.done/$0"

# Done
echo ""
echo "Info: 1st step complete."

echo ""
echo "REBOOT NOW and afterwards run 'sudo bash 2nd-migrate-and-set-immutable.sh' to continue installation."
echo ""
