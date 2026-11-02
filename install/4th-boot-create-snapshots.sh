#!/usr/bin/bash

#MIT License
#Copyright (c) 2026 allmun

set -e

# Prevent running this script muliple times
if [ -f "/var/aida/.done/$0" ]; then
    echo ""; echo "$0 has already been executed"
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


# Code create new snapshot and run a software update
echo "Creating new snapshot ..."
aida-create

echo "Updating software in new snapshot in chroot"
aida-update

# Start grub-btrfsd deamon needed for adding snapshots to grub menu
systemctl enable --now grub-btrfsd

# Create a snapshot of the current root
echo "Enable new snapshot in grub menu ..."
aida-create

echo "Updating: Running sw update ..."
aida-update

echo "Switching: Running grub-mkconfig ..."
aida-switch

# Mark this script as executed
touch "/var/aida/.done/$0"

echo ""
echo "All done".
echo ""
echo "Reboot now to make changes permanent and run 'sudo bash 5th-boot-make-immutable' after the rebooting"
