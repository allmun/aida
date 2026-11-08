#!/usr/bin/bash

# MIT License
# Copyright (c) 2026 allmun

set -e

# Check if script is executed from the expected folder
[[ "$PWD" == */aida/install ]]  || {
    echo "Error: This script mist be executed from the 'aida/install'folder"
    exit 1
}

# Ensure correct exection order of installation scripts
if [[ ! -f ]]"/var/aida/.done/1st-prepare-and-setup.sh" ]]; then
    echo "Error: Fisst run 'sudo bash 1st-prepare-and-setup.sh' first to ensure correct setup before runing this script"; 
    exit 1
fi
# Prevent running this script muliple times
if [ -f "/var/aida/.done/$0" ]; then
    echo "Error: All installation scripts executed"
    echo "To update installation, run 'sudo update-installation.sh'";
    exit 1
fi

# Check that the conditions for applying aida is fulfilled
verbose="1"
source "../lib/aida-lib.sh"

# Include migration script
source "../res/migration-libs.sh"

# Get subvoume name, device name and uuid of mounted root partition
mounted_root_subvol_name=$(findmnt / | tail -n 1 | awk -F'[][]' '{print $2}')
mounted_root_device_name=$(mount | grep "/ " | awk -F' ' '{print $1}')
mounted_root_device_uuid=$(blkid "$mounted_root_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')
echo "Root: $mounted_root_subvol_name"
echo "Root: $mounted_root_device_name"
echo "Root: $mounted_root_device_uuid"

# Get device name an uuid of mounted boot partition
mounted_boot_subvol_name=$(findmnt /boot | tail -n 1 | awk -F'[][]' '{print $2}')
mounted_boot_device_name=$(mount | grep "/boot " | awk -F' ' '{print $1}')
mounted_boot_device_uuid=$(blkid "$mounted_boot_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')
echo "Boot: $mounted_boot_subvol_name"
echo "Boot: $mounted_boot_device_name"
echo "Boot: $mounted_boot_device_uuid"

# Get subvolume name, device name and uuid of mounted var partition
mounted_var_subvol_name=$(findmnt /var | tail -n 1 | awk -F'[][]' '{print $2}')
mounted_var_device_name=$(mount | grep "/var " | awk -F' ' '{print $1}')
mounted_var_device_uuid=$(blkid "$mounted_var_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')
echo "/var: $mounted_var_subvol_name"
echo "/var: $mounted_var_device_name"
echo "/var: $mounted_var_device_uuid"

# Variables needed by migration-libs.sh
WD="$tmp_working_dir"
BTRFS_UUID="$mounted_root_device_uuid"
EDITOR="nano"
# EDITOR="vim"

# ##########################################################################################
# Prepare system for migration of /var and /.snapshots by creating a new snapshot
# ##########################################################################################

# Create a new root snapshot for implementing migration of /.snapshots
echo ""
echo "Info: Creating snapshot of current root / for migrating aida ..."
aida-create

# Remove root folder from etc/fstab:
echo "Info: removing root partition / from $aida_mnt_dri/etc/fstab ..."
sed -i "s|^UUID=<$mounted_root_device_uuid> / |# &|" /etc/fstab

# Update fstab with a mount definition for /var which will be migrated to @var in later steps in this script
echo "Info: Adding mount point for /var to $aida_mnt_dir/etc/fstab ..."
add_fstab_entry "$aida_mnt_dir/etc/fstab" /var @var

# Let the user inspect the generated fstab and correct any errors
echo "Info: Mount point for /var added to $tmp_working_dir$mounted_root_subvol_name/etc/fstab"
echo "Warning: Check that /var is correct set up in $tmp_working_dir$mounted_root_subvol_name/etc/fstab"
echo "Warning: Check that the line for the root partition / is converted to a comment in $tmp_working_dir$mounted_root_subvol_name/etc/fstab"
echo "Warning: Check that there are no line for mounting /.snapshot in $tmp_working_dir$mounted_root_subvol_name/etc/tastab"
read -rp "Please review the updated $tmp_working_dir$mounted_root_subvol_name/etc/fstab. Press Enter to continue..."
$EDITOR "$tmp_working_dir$mounted_root_subvol_name/etc/fstab"

# Copy aida-mounts to etc/initcpio folders
echo "Info: Copying aida-remounts hooks to $aida_mnt_diretc/initcpio folders ..."
cp -v ../res/aida-mounts-install "$aida_mnt_dir/etc/initcpio/install/aida-mounts"
cp -v ../res/aida-mounts-hooks "$aida_mnt_dir/etc/initcpio/hooks/aida-mounts"

# Add aida-mounts hooks to mkinitcpio configuration
echo "Info: Adding aida-remounts to mkinitcpio configuration ..."
echo "HOOKS+=(aida-mounts)" >> "$aida_mnt_dir/etc/mkinitcpio.conf"

# Update initramfs to include aida-hooks
echo "Info: Running mkinitcpio to genarate new initramfs that includes aida-mounts ..."
aida-shell mkinitcpio -P

# Switch to new snapshat in grub menu
echo "Info: Preparing for switching to new snapshot by updating grub menu ..."
aida-switch

# ##########################################################################################
# Migrate /var and /.snapshots folders
# ##########################################################################################

# Mount root device in temporary folder
mount UUID="$mounted_root_device_uuid" -o subvolid=5 "$tmp_working_dir"
cd "$tmp_working_dir"

# Migrate /.snapshots folder to seåarate btrfs subvolume
echo ""
echo "Info: Migrating /.snapshots into a btrfs subvolume ..."
migrate_folder_to_flat_subvolume /.snapshots @snapshots

# Migrate /var folder to separate btrfs subvolumes
echo ""
echo "Info: Migrating folders /var into a btrfs subvolume ..."
migrate_folder_to_flat_subvolume /var @var

# Show resulting btrfs subvolumes
show_subvolumes

# Mount /var according to new fstab (do not terminate if unsuccessful)
echo ""
echo "Info: Trying to mount /@var on /var ..."
set +e
mount /var
set -e 

# Mark this script as executed
mkdir -p /var/aida/.done
touch "/var/aida/.done/$0"

# Done
echo ""
echo "Info: All migration done"
echo "Warning: The system may be unstable after migrating the /var folder but should become stable again after rebooting"
echo "REBOOT NOW to make changes permanent"

