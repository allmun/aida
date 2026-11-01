#!/usr/bin/bash

#MIT License
#Copyright (c) 2026 allmun

set -e

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# Check if script is executed from the expected folder
[[ "$PWD" == */aida/install ]]  || {
    echo "This script mist be executed from the 'aida/install'folder"
    exit 1
}

# Save this location for later
hereis_aida_install="$PWD"

# Check that the conditions for applying aida is fulfilled
verbose="1"
source "../lib/aida-lib.sh"

echo ""
echo "Starting steps to prepare for aida ..."

# Include migration script
source ./migration-libs.sh

# Craete important folders
tmp_working_dir="/mnt"
snapshot_dir="/.snapshots"
aida_var_dir="/var/aida"
mkdir -p "$tmp_working_dir"
mkdir -p "$snapshot_dir"
mkdir -p "$aida_var_dir/mnt"

# For debug:
echo "dummy" > "$snapshot_dir/dummy.txt"

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

# If root file system is writable, start grub-btrfs, otherwise check if we can proceed
if [ -n "$(grep ' / ' /proc/mounts | grep "[[:space:]]rw[[:space:],]")" ]; then
  # Root file system is read-write
  # Enable and start grub-btrfs system service
  systemctl enable --now grub-btrfsd.service
else
  # Root file system is read-only
  # Check if dependencies are installed
  if [ -z "$(pacman -Qs btrfs-progs)" ]; then
    echo "ERROR: btrfs-progs is needed but installed on read-only root file system"
    exit 1
  fi
  if [ -z "$(pacman -Qs grub-btrfs)" ]; then
    echo "ERROR: grub-btrfs is needed but installed on read-only root file system"
    exit 1
  fi
  echo "Info: Root file system is read-only but dependencies are installed"
fi

# Variables needed by migration-libs.sh
WD="$tmp_working_dir"
BTRFS_UUID="$mounted_root_device_uuid"

# Define the editor for editing the /etc/fstab.
EDITOR="nano"
# EDITOR="vim"

# Migrate ordinary folder to separate btrfs subvolumes
echo "Migrating folders /var and /.snapshots into btrfs subvolumes ..."
# Mount root device in temporary folder
mount UUID="$mounted_root_device_uuid" -o subvolid=5 "$tmp_working_dir"
cd "$tmp_working_dir"

# Migrate /.snapshots
echo "Migrating /.snapshots ..."
migrate_folder_to_flat_subvolume /.snapshots @snapshots
add_fstab_entry /etc/fstab /.snapshots @snapshots

# Migrate /var
echo "Migrating /var"
migrate_folder_to_flat_subvolume /var @var
add_fstab_entry /etc/fstab /var @var

# Show resulting btrfs subvolumes
show_subvolumes

# Let the user inspect the generated fstab and correct any errors
echo "The /var and the /.snapshots folders were migrated to subvolumes"
read -rp "Please review the updated $tmp_working_dir$mounted_root_subvol_name/etc/fstab. Press Enter to continue..."
$EDITOR "$tmp_working_dir$mounted_root_subvol_name/etc/fstab"

# Remount according to the update fstab
echo "Remounting file system according to updated fstab"
systemctl daemon-reload
#mount -o remount -a
set +e
umount -a
mount -a
mount -a
set -e

# Update grub menu
echo "Updating the grub boot menu ..."
grub-mkconfig -o /boot/grub/grub.cfg

# Rename this script to ensure that it's only executed once
cd "$hereis_aida_install"
mv "./$0" "./do-not-run-again_$0"

# Done
echo ""
echo "2nd step complte."
echo ""
echo "Reboot not and run 'sudo bash 3rd-boot-install-aida' when system is booted."
echo ""
