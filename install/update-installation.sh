#!/usr/bin/bash

#MIT License
#Copyright (c) 2026 allmun

set -e

if [[ "$@" != "1st-prepare-and-setup.sh" && "$@" != "2nd-migrate-and-set-immutable.sh" ]]; then
    # Ensure correct exection order of installation scripts
    if [[ ! -f "/var/aida/.done/1st-prepare-and-setup.sh" ]]; then
        echo "Run 'sudo bash 1st-prepare-and-setup.sh' first to ensure correct setup before runing this script";
        exit 1
    fi
    if [[ ! -f "/var/aida/.done/2nd-migrate-and-set-immutable.sh" ]]; then
        echo "Run 'sudo bash 2nd-migrate-and-set-immutable.sh' first to ensure correct setup before runing this script";
        exit 1
    fi
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
echo "Starting steps to install aida files ..."

# Remove old installation and potential junk but keep mnt and snapshots
echo ""
echo "Removing old install from /var/aida/ ..."
for dir in /var/aida/*/; do
    dir=${dir%/}
    if [[ "$dir" != "" && "$dir" != "/" && "$dir" != "/var/aida/mnt" && "$dir" != "/var/aida/.done" ]]; then
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
    echo "Updating of aida done"
fi
