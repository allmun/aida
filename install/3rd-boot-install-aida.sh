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
echo "Starting steps to install aida files ..."

# Remove old installation and potential junk but keep mnt and snapshots
echo ""
echo "Removing old install from /var/aida/ ..."
for dir in /var/aida/*/; do
    dir=${dir%/}
    if [[ "$dir" != "" && "$dir" != "/" && "$dir" != "/var/aida/mnt" ]]; then
        echo "$dir"
        rm -rf "$dir"
    fi
done

# Ensure mount points for aida framework
echo ""
echo "Creating mount points for aida ..."
mkdir -p /var/aida/mnt
mkdir -p /var/aida/bin
mkdir -p /var/aida/lib
mkdir -p /var/aida/config

# Copy files from Project folder to destination in /var/aida
echo ""
echo "Copying files ..."
cp -r ../bin/* /var/aida/bin/
cp -r ../lib/* /var/aida/lib/
cp -r ../config/* /var/aida/config/


# Check if root file system is read-write
if [ -n "$(grep '/ ' /proc/mounts | grep "[[:space:]]rw[[:space:],]")" ]; then
    # Root file system is read-write
    # Remove old links to aida binaries
    set +e
    rm /usr/local/bin/aida-*
    set -e
    # Create new links to aida binaries
    for srcfile in /var/aida/bin/*; do
        dstfile=${srcfile#/var/aida/bin/}
        ln -s $srcfile /usr/local/bin/$dstfile
    done
    echo "All update-aida done.".
else
  # Root file system is read-only
    # Create new snapshot
    aida-create
    # Remove old links to aida binaries
    set +e
    rm /var/aida/mnt/usr/local/bin/aida-*
    set -e
    # Create new links to aida binaries
    for srcfile in /var/aida/bin/*; do
        dstfile=${srcfile#/var/aida/bin/}
        ln -s $srcfile /var/aida/mnt/usr/local/bin/$dstfile
    done
    echo "All update-aida done. Run 'aida-shell' or 'aida-update' and finally 'aida-switch' to make changes permanent".
fi

# Rename this script to ensure that it's only executed once as 3rd-boot-install-aida.sh
# but also create a copy that allows it to be executed as update-installation.sh
# Rename this script to ensure that it's only executed once
cd "$hereis_aida_install"
if [ -f ./3rd-boot-install-aida.sh ]; then
    # Copy this script for allowing future updates
    cp "./$0" ./update-installation.sh
    # Rename this script to ensure that it's only executed once
    mv "./$0" "./do-not-run-again_$0"
fi

# Done
echo ""
echo "3rd step complte."
echo ""
echo "Reboot not and run 'sudo bash 4th-boot-create-snapshots' when system is booted."
echo ""
