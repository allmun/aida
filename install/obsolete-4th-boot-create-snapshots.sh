#!/usr/bin/bash

#MIT License
#Copyright (c) 2026 allmun

set -e

# Ensure correct exection order of installation scripts
if [[ ! -f ]]"/var/aida/.done/1st-boot-initial-prepare.sh" ]]; then
    echo "Run 'sudo bash 1st-boot-initial-prepare.sh' first to ensure correct setup before runing this script"; exit 1
fi
if [[ ! -f "/var/aida/.done/2nd-boot-prepare-aida.sh" ]]; then
    echo "Run 'sudo bash 2nd-boot-prepare-aida.sh' first to ensure correct setup before runing this script"; exit 1
fi
if [[ ! -f "/var/aida/.done/3rd-boot-install-aida.s" ]]; then
    echo "Run 'sudo bash 3rd-boot-install-aida.sh' first to ensure correct setup before runing this script"; exit 1
fi
# Prevent running this script muliple times
if [ -f "/var/aida/.done/$0" ]; then
    echo ""; echo "$0 has already been executed"
    if [[ ! -f "/var/aida/.done/2nd-boot-prepare-aida.sh" ]]; then
        echo "Run 'sudo bash 2nd-boot-prepare-aida.sh' to continue installation"; exit 1
    fi
    if [[ ! -f "/var/aida/.done/3rd-boot-install-aida.sh" ]]; then
        echo "Run 'sudo bash 3rd-boot-install-aida.sh' to continue installation"; exit 1
    fi
    if [[ ! -f "/var/aida/.done/4th-boot-create-snapshots.sh" ]]; then
        echo "Run 'sudo bash 4th-boot-create-snapshots.sh' to continue installation"; exit 1
    fi
    if [[ ! -f "/var/aida/.done/5th-boot-make-immutable.sh" ]]; then
        echo "Run 'sudo bash 5th-boot-make-immutable.sh' to continue installation"; exit 1
    fi
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
mkdir -p /var/aida/.done
touch "/var/aida/.done/$0"

echo ""
echo "All done".
echo ""
echo "Reboot now to make changes permanent and run 'sudo bash 5th-boot-make-immutable' after the rebooting"
