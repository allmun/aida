#!/usr/bin/bash

#MIT License
#Copyright (c) 2026 allmun

set -e

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

# Create and mount new snapshot
echo "Creating snapshot ..."
mount_root_subvol

# In /etc/fstab make root partition read-only:
sed -Ei.bak \
  '/^[[:space:]]*[^#[:space:]]+[[:space:]]+\/[[:space:]]+[^[:space:]]+[[:space:]]+/ s/^([[:space:]]*[^#[:space:]]+[[:space:]]+\/[[:space:]]+[^[:space:]]+[[:space:]]+)([^[:space:]]+)/\1\2,ro/' \
  /var/aida/mnt/etc/fstab

# Allow the user to inspect the generated fstab
echo ""
echo "Created /etc/fstab.bak"
echo "Added 'ro' to root partition in /etc/fstab:"
echo "$(grep '/ ' /var/aida/mnt/etc/fstab)"
read -rp "Please, review entire /etc/fstab. Press Enter to continue..."
# Open /etc/fstab in the nano text editor:
nano /var/aida/mnt/etc/fstab

# Swithc to new snapshot by updating the grub menu
switch_to_new_snapshot

# Mark this script as executed
mkdir -p /var/aida/.done
touch "/var/aida/.done/$0"

echo ""
echo "All done".
echo ""
echo "Reboot now to make changes permanent"
