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

# Rename this script to ensure that it's only executed once
cd "$hereis_aida_install"
mv "./$0" "./do-not-run-again_$0"

# Done
echo ""
echo "1st step complete."
echo ""
echo "Run 'sudo bash 2nd-boot-prepare-aida.sh' to continue installation."
echo ""
