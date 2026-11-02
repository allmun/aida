#!/usr/bin/bash

#MIT License
#Copyright (c) 2026 allmun

set -e

# Prevent running this script muliple times
if [ -f "/var/aida/.done/$0" ]; then
    echo ""; echo "$0 has already been executed"
    [[ -f "/var/aida/.done/2nd-boot-prepare-aida.sh" ]] || echo "Run 'sudo bash 2nd-boot-prepare-aida.sh' to continue installation"; exit 1
    [[ -f "/var/aida/.done/3rd-boot-install-aida.sh" ]] || echo "Run 'sudo bash 3rd-boot-install-aida.sh' to continue installation"; exit 1
    [[ -f "/var/aida/.done/4th-boot-create-snapshots.sh" ]] || echo "Run 'sudo bash 4th-boot-create-snapshots.sh' to continue installation"; exit 1
    [[ -f "/var/aida/.done/5th-boot-make-immutable.sh" ]] || echo "Run 'sudo bash 5th-boot-make-immutable.sh' to continue installation"; exit 1
    echo "All installation scripts executed. If updating, run 'sudo update-installation.sh'"; echo ""; exit 1
fi


if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# Check if script is executed from the expected folder
[[ "$PWD" == */aida/install ]]  || {
    echo "This script mist be executed from the 'aida/install'folder"
    exit 1
}

# Check that the conditions for applying aida is fulfilled
verbose="1"
source "../lib/aida-lib.sh"

echo ""
echo "Intalling dependencies ..."
pacman -Syu --noconfirm
pacman -Syu --noconfirm btrfs-progs grub-btrfs inotify-tools

# Create important folders
mkdir -p /.snapshots
mkdir -p /var/aida/mnt

echo ""
echo "Starting services ..."
systemctl enable grub-btrfsd

# Start grub-btrfsd service
systemctl start grub-btrfsd.service

# Mark this script as executed
touch "/var/aida/.done/$0"

# Done
echo ""
echo "1st step complete."
echo ""
echo "Run 'sudo bash 2nd-boot-prepare-aida.sh' to continue installation."
echo ""
