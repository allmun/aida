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

# Rename this script to ensure that it's only executed once
cd "$hereis_aida_install"
mv "./$0" "./do-not-run-again_$0"


echo ""
echo "All done".
echo ""
echo "Reboot now to make changes permanent"
