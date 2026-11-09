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

# Prevent running this script muliple times
if [ -f "/var/aida/.done/$0" ]; then
    if [[ ! -f "/var/aida/.done/2nd-migrate-and-set-immutable.sh" ]]; then
        echo "Info: Run 'sudo bash 2nd-migrate-and-set-immutable.sh' to continue installation"; exit 1
    fi
    echo "Info: All installation scripts executed."
    echo "Info: To update the installation, run 'sudo update-installation.sh'";
    exit 1
fi

# Check that script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root"
  exit 1
fi

# Check that the conditions for applying aida is fulfilled
verbose="1"
source "../lib/aida-lib.sh"

# #########################################################################################
# Create essentail folder and symbolic links
# #########################################################################################

# Define important folders
tmp_working_dir="/mnt"
snapshot_dir="/.snapshots"
aida_var_dir="/var/aida"
aida_mnt_dir="$aida_var_dir/mnt"
aida_config_dir="$aida_var_dir/config"

# Craete important folders
mkdir -p "$tmp_working_dir"
mkdir -p "$snapshot_dir"
mkdir -p "$aida_mnt_dir"
mkdir -p "$aida_var_dir/.done"

# Create important symbolic links
sysrootlnk="/sysroot"
sysroottgt="/"
if [[ -L "$sysrootlnk" || -d "$sysrootlnk" || -f "$sysrootlnk" ]]; then
    # link, folder, or file with this already name exists
    if [[ -L "$sysrootlnk" && -e "$sysroottgt" ]]; then
        echo "Info: The symbolic link $sysrootlnk exists and points to the valid target $sysroottgt as expected"
    else
        echo "Error: The a file, folder, or link with the name $sysrootlnk exists but does not points to the valid target $sysroottgt as expected, cannot continue without symbolic link $sysrootlnk -> $sysroottgt"
        exit 1
    fi
else
    # neither link, folder, or file with this name exist
    echo "Info: Creating symbolic link $sysrootlnk -> $sysroottgt"
    ln -s "$sysroottgt" "$sysrootlnk"
fi

# #########################################################################################
# Update software and install packages frequired for aida and enable system services
# #########################################################################################

# Install essential packages after updating already installed packages
echo ""
echo "Info: Updating all packages and Intalling btrfs-progs grub-btrfs inotify-tools ..."
pacman -Syu --noconfirm --needed btrfs-progs grub-btrfs inotify-tools

# Enable and start grub-btrfs system service
echo ""
echo "Info: Enabling grub-btrfsd.service ..."
systemctl enable --now grub-btrfsd.service

# #########################################################################################
# Install aida into /var/aida
# #########################################################################################

# Install aida binaries, librararies, etc by running update-installation.sh:
echo ""
echo "Info: calling script to install binaries etc ..."
bash ./update-installation.sh "1st-prepare-and-setup.sh"

# #########################################################################################
# Generate declarative configuration based on existing system configuration
# #########################################################################################

# Replace default configuration to existing system configuration
echo ""
echo "Info: Generating aida declarative configuration from existing system configuration ..."

# Generate pacman packages declarative configuration
pacman -Qenq > "$aida_config_dir/pacman.packages"

# Generate systemd system services declarative configuration
systemctl list-unit-files --type=service --state=enabled | awk '$1 ~ /\.service$/ { print $1 }' > "$aida_config_dir/system.services"

# Generate systemd user services declarative configuration
systemctl list-unit-files --type=service --state=enabled --user | awk '$1 ~ /\.service$/ { print $1 }' > "$aida_config_dir/user.services"

# #########################################################################################
# Migrate /var and /.snapshot folders
# #########################################################################################

# Include migration resource
source "../res/migration-libs.sh"

# Get subvoume name, device name and uuid of mounted root partition
mounted_root_subvol_name=$(findmnt / | tail -n 1 | awk -F'[][]' '{print $2}')
mounted_root_device_name=$(mount | grep "/ " | awk -F' ' '{print $1}')
mounted_root_device_uuid=$(blkid "$mounted_root_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')
echo "Root: $mounted_root_subvol_name"
echo "Root: $mounted_root_device_name"
echo "Root: $mounted_root_device_uuid"

# Variables needed by migration-libs.sh
WD="$tmp_working_dir"
BTRFS_UUID="$mounted_root_device_uuid"
EDITOR="nano"
# EDITOR="vim"

# Mount root device in temporary folder for creation of btrfs subvolumes
mount UUID="$mounted_root_device_uuid" -o subvolid=5 "$tmp_working_dir"
cd "$tmp_working_dir"

# Migrate /.snapshots folder to seåarate btrfs subvolume
# Notice that we do NOT add a mounting point definition for /.snapshots in /etc/fstab
echo ""
echo "Info: Migrating /.snapshots into a btrfs subvolume ..."
migrate_folder_to_flat_subvolume /.snapshots @snapshots

# Migrate /var folder to separate btrfs subvolumes
echo ""
echo "Info: Migrating folders /var into a btrfs subvolume ..."
migrate_folder_to_flat_subvolume /var @var

# Update fstab with a mount definition for /var which will be migrated to @var in later steps in this script
echo "Info: Adding mount point for /var to /etc/fstab ..."
add_fstab_entry "/etc/fstab" /var @var

# Let the user inspect the generated fstab and correct any errors
echo "Info: Mount point for /var added to /etc/fstab"
echo "Warning: Check that /var is correctly set up in /etc/fstab"
read -rp "Action: Please review the updated /etc/fstab now. Press Enter to continue..."
$EDITOR "/etc/fstab"

# #########################################################################################
# Finish and exit
# # #########################################################################################

# Mark this script as executed (it is premature but cannot be done after migration and before reboot)
mkdir -p /var/aida/.done
touch "/var/aida/.done/$0"
mkdir -p "$WD/@var/aida/.done"
touch "$WD/@var/aida/.done/$0"

# Done
echo ""
echo "Info: 1st step complete."

echo ""
echo "REBOOT NOW and afterwards run 'sudo bash 2nd-migrate-and-set-immutable.sh' to continue installation."
echo ""
