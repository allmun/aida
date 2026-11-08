#!/usr/bin/bash

# MIT License
# Copyright (c) 2026 allmun

set -e

# Check if script is executed from the expected folder
[[ "$PWD" == */aida/install ]]  || {
    echo "Error: This script mist be executed from the 'aida/install'folder"
    exit 1
}

# Prevent running this script muliple times
if [ -f "/var/aida/.done/$0" ]; then
    if [[ ! -f "/var/aida/.done/4th-boot-create-snapshots.sh" ]]; then
        echo "Info: Run 'sudo bash 4th-boot-create-snapshots.sh' to continue installation"; exit 1
    fi
    if [[ ! -f "/var/aida/.done/5th-boot-make-immutable.sh" ]]; then
        echo "Info: Run 'sudo bash 5th-boot-make-immutable.sh' to continue installation"; exit 1
    fi
    echo "Info: All installation scripts executed."
    echo "Info: To update the installation, run 'sudo update-installation.sh'"; 
    exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run as root"
  exit 1
fi

# Check that the conditions for applying aida is fulfilled
verbose="1"
source "../lib/aida-lib.sh"

# Craete important folders
tmp_working_dir="/mnt"
snapshot_dir="/.snapshots"
aida_var_dir="/var/aida"
aida_mnt_dir="$aida_var_dir/mnt"
mkdir -p "$tmp_working_dir"
mkdir -p "$snapshot_dir"
mkdir -p "$aida_mnt_dir"

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
    echo "Info: Creating symbolic link $sysrootlnk" -> "$sysroottgt"
    ln -s "$sysrootlnk" "$sysroottgt"
fi

# Install essential packages
echo ""
echo "Info: Updating all packages and Intalling btrfs-progs grub-btrfs inotify-tools ..."
pacman -Syu --noconfirm --needed btrfs-progs grub-btrfs inotify-tools

# If root file system is writable, start grub-btrfs, otherwise check if we can proceed
echo ""
echo "Info: Enabling grub-btrfsd.service
if [ -n "$(grep ' / ' /proc/mounts | grep "[[:space:]]rw[[:space:],]")" ]; then
  # Root file system is read-write"
  # Enable and start grub-btrfs system service
  systemctl enable --now grub-btrfsd.service
else
  # Root file system is read-only
  # Check if dependencies are installed
  if [ -z "$(pacman -Qs btrfs-progs)" ]; then
    echo "Error: btrfs-progs is needed but installed on read-only root file system"
    exit 1
  fi
  if [ -z "$(pacman -Qs grub-btrfs)" ]; then
    echo "Error: grub-btrfs is needed but installed on read-only root file system"
    exit 1
  fi
  echo "Info: Root file system is read-only but dependencies are installed"
fi

# Install aida binaries, librararies, etc by running update-installation.sh:
bash ./update-installation.sh

# Replace default configuration to existing system configuration
echo ""
echo "Info: Generating aida declarative configuration from existing system configuration ..."
# TODO generate pacman.packages
# TODO generate system.services
# TODO generate user.services

# Create two snapshots of the current root (one for an unmodified fallback and one for installint aida)
echo ""
echo "Info: Creating fallback snapshot of current root /"
aida-create
umount "$aida_mnt_dir"
echo "Info: Creating snapshot of current root / for installing aida"
aida-create
# Run declarative updater to verify that it works
echo "Info: Running aida-update to update system software to update aida declaration..."
aida-update

# Switch to new snapshat in grub menu
echo ""
echo "Info: Switching to new snapshot by updating grub menu ..."
aida-switch

# Mark this script as executed
mkdir -p /var/aida/.done
touch "/var/aida/.done/$0"

# Done
echo ""
echo "Info: 1st step complete."
echo ""
echo "Reboot and Run 'sudo bash 2nd-migrate-and-set-immutable.sh' to continue installation."
echo ""
