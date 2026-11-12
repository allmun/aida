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

# Ensure correct exection order of installation scripts
if [[ ! -f "/var/aida/.done/1st-prepare-and-setup.sh" ]]; then
    echo "Error: First run 'sudo bash 1st-prepare-and-setup.sh' first to ensure correct setup before runing this script";
    exit 1
fi

# Prevent running this script muliple times
if [ -f "/var/aida/.done/$0" ]; then
    echo "Error: All installation scripts executed"
    echo "To update installation, run 'sudo update-installation.sh'";
    exit 1
fi

# Check that the conditions for applying aida is fulfilled
verbose="1"
source "../lib/aida-lib.sh"

# #########################################################################################
# Cleanup from 1st-prepare-and-setup.sh
# #########################################################################################

echo ""
echo "Cleaning temporary folders created by 1st-prepare-and-setup.sh"
[[ -d "/var_temp" ]] && rm -rf /var_temp
[[ -d "/.snapshots_temp" ]] && rm -rf /.snapshots_temp

# #########################################################################################
# Move folders at / that must remain writable
# #########################################################################################

move_folder() {
    local src="$1"
    local dst="$2"
    local name="$3"
    
    if [[ -z "$src" ]]; then
        echo "Nothing to move: Folder $src does not exist"
        return
    fi
    
    if [[ ! -d "$src" ]]; then
        echo "Nothing to move: The $src is not a regular folder"
        return
    fi

    if [[ -n "$(findmnt $src)" ]]; then
        echo "Nopthing to move: The $src is a mount point"
        return
    fi
    
    if [[ -d "$dst" ]]; then
        echo "Backing up $dst to ${dst}_backup"
        mv "$dst" "${dst}_backup"
    fi

    mv "$src" "$dst"
    ln -s "$dst" "$src"
}

echo ""
echo "Moving and linking /mnt /opt /root /srv and /tmp to writable folder ..."
move_folder /mnt /var/rootmnt
move_folder /opt /var/opt
move_folder /root /home/root
move_folder /srv /var/srv
move_folder /usr/local /var/usrlocal
move_folder /usr/tmp /var/usrtmp

# #########################################################################################
# Define essentail variables
# #########################################################################################

# Define important folders
tmp_working_dir="/mnt"
snapshot_dir="/.snapshots"
aida_var_dir="/var/aida"
aida_mnt_dir="$aida_var_dir/mnt"
aida_config_dir="$aida_var_dir/config"

# #########################################################################################
# Temporarily mount @snapshots on /.snapshot
# #########################################################################################

# Get subvoume name, device name and uuid of mounted root partition
mounted_root_subvol_name=$(findmnt / | tail -n 1 | awk -F'[][]' '{print $2}')
mounted_root_device_name=$(mount | grep " / " | awk -F' ' '{print $1}')
mounted_root_device_uuid=$(blkid "$mounted_root_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')
echo "Root: $mounted_root_subvol_name"
echo "Root: $mounted_root_device_name"
echo "Root: $mounted_root_device_uuid"
# mount /.snapshots
if [[ -z "$(findmnt $snapshot_dir)" ]]; then 
    echo "Info: Mounting /.snapshots ..."
    mount -t btrfs -o subvol=@snapshots,defaults,noatime,compress=lzo "$mounted_root_device_name" "$snapshot_dir"
fi

# #########################################################################################
# Create first snapshots and update according to declarative configuration
# #########################################################################################

# Create snapshot
echo ""
echo "Info: Creating first snapshot ..."
mount_root_subvol

# Update snapshot to declared configuration
echo ""
echo "Info: Updating snapshot to declared configuration ..."
update_root_subvol

# #########################################################################################
# Install initcpio hooks for (re)mounting root /, ./snapshots,and /etc overlay
# #########################################################################################

# Copy aida-mounts to etc/initcpio folders
echo "Info: Copying aida-remounts hooks to $aida_mnt_diretc/initcpio folders ..."
cp -v ../res/aida-mounts-install "$aida_mnt_dir/etc/initcpio/install/aida-mounts"
cp -v ../res/aida-mounts-hooks "$aida_mnt_dir/etc/initcpio/hooks/aida-mounts"

# Add poverlayfs to mkinitcpio configuration
if [[ -z "$(cat $aida_mnt_dirt/etc/mkinitcpio.conf | grep 'MODULES+=(overlay)')" ]]; then
    echo "Info: Adding aida-remounts to mkinitcpio configuration ..."
    echo "MODULES+=(overlay)" >> "$aida_mnt_dir/etc/mkinitcpio.conf"
fi

# Add aida-mounts hooks to mkinitcpio configuration
if [[ -z "$(cat $aida_mnt_dirt/etc/mkinitcpio.conf | grep 'HOOKS+=(aida-mounts)')" ]]; then
    echo "Info: Adding aida-remounts to mkinitcpio configuration ..."
    echo "HOOKS+=(aida-mounts)" >> "$aida_mnt_dir/etc/mkinitcpio.conf"
fi

# Update initramfs to include aida-hooks
echo "Info: Running mkinitcpio to genarate new initramfs that includes aida-mounts ..."
run_chroot_shell_commands /usr/bin/mkinitcpio -P

# Remove mount point defintion for root folder in etc/fstab:
echo "Info: removing root partition / from $aida_mnt_dir/etc/fstab ..."
sed -i "s|^UUID=$mounted_root_device_uuid / |# &|" "$aida_mnt_dir/etc/fstab"

# #########################################################################################
# Switch to new snapshot
# # #########################################################################################

# Update grub menu to point at new snapshot
echo ""
echo "Info: Updating grub menu to point to snapshot"
switch_to_new_snapshot

# #########################################################################################
# Finish and exit
# # #########################################################################################

# Mark this script as executed (it is premature but cannot be done after migration and before reboot)
mkdir -p /var/aida/.done
touch "/var/aida/.done/$0"

# Done
echo ""
echo "Info: 2nd step complete."

echo ""
echo "REBOOT NOW and afterwards run 'sudo bash 2nd-migrate-and-set-immutable.sh' to continue installation."
echo ""
