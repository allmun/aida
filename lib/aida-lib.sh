#!/usr/bin/bash

#MIT License
#Copyright (c) 2026 allmun

# Disable verbose information if not set in calling script
verbose=${verbose:-"0"}
#verbose=${verbose:-"1"}

if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# Exit on any error
set -e

# Framework folders
#aida_bin_folder="/var/aida/mnt/rootsubvol/usr/local/bin"
aida_bin_folder="/var/aida/bin"
aida_lib_folder="/var/aida/lib"
aida_etc_folder="/var/aida/etc"
aida_pkg_folder="/var/aida/pkg"
aida_mnt_dir="/var/aida/mnt"
snapshot_dir="/.snapshots"

# Get subvoume name, device name and uuid of mounted root partition
mounted_root_subvol_name=$(mount | grep "/ " | awk -F'subvol=/' '{print $2}' | awk -F')' '{print $1}')
mounted_root_device_name=$(mount | grep "/ " | awk -F' ' '{print $1}')
mounted_root_device_uuid=$(blkid "$mounted_root_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')

# Get device name an uuid of mounted boot partition
mounted_boot_subvol_name=$(mount | grep "/boot " | awk -F'subvol=/' '{print $2}' | awk -F')' '{print $1}')
mounted_boot_device_name=$(mount | grep "/boot " | awk -F' ' '{print $1}')
mounted_boot_device_uuid=$(blkid "$mounted_boot_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')

# Get device name an uuid of mounted boot/grub partition
mounted_boot_grub_subvol_name=$(mount | grep "/boot/grub " | awk -F'subvol=/' '{print $2}' | awk -F')' '{print $1}')
mounted_boot_grub_device_name=$(mount | grep "/boot/grub " | awk -F' ' '{print $1}')
mounted_boot_grub_device_uuid=$(blkid "$mounted_boot_grub_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')

# Get subvolume name, device name and uuid of mounted var partition
mounted_var_subvol_name=$(mount | grep "/var " | awk -F'subvol=/' '{print $2}' | awk -F')' '{print $1}')
mounted_var_device_name=$(mount | grep "/var " | awk -F' ' '{print $1}')
mounted_var_device_uuid=$(blkid "$mounted_var_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')

# Get subvolume name, device name and uuid of mounted var partition
mounted_etc_subvol_name=$(mount | grep "/etc " | awk -F'subvol=/' '{print $2}' | awk -F')' '{print $1}')
mounted_etc_device_name=$(mount | grep "/etc " | awk -F' ' '{print $1}')
mounted_etc_device_uuid=$(blkid "$mounted_etc_device_name" | awk -F'UUID="' '{print $2}' | awk -F'"' '{print $1}')


# Displays information if $verbose != 0
verbose_echo() {
    if [[ "$verbose" != "0" ]]; then
        echo "$@";
    fi
}

# Runs 'ls' command information if $verbose != 0
verbose_ls() {
    if [[ "$verbose" != "0" ]]; then
        ls "$@";
    fi
}

# Show device name, uuid, and subvol name for root, boot/grub, /etc, and /var
verbose_echo "Folder / on $mounted_root_device_name uuid=$mounted_root_device_uuid subvol=$mounted_root_subvol_name"
verbose_echo "Folder /boot on $mounted_boot_device_name uuid=$mounted_boot_device_uuid subvol=$mounted_boot_subvol_name"
verbose_echo "Folder /boot/grub on $mounted_boot_grub_device_name uuid=$mounted_boot_grub_device_uuid subvol=$mounted_boot_grub_subvol_name"
verbose_echo "Folder /var on $mounted_var_device_name uuid=$mounted_var_device_uuid subvol=$mounted_var_subvol_name"
verbose_echo "Folder /etc on $mounted_etc_device_name uuid=$mounted_etc_device_uuid subvol=$mounted_etc_subvol_name"

# Check if root is on a btrfs file system as required by aida
if [[ "$(stat -f --format="%T" /)" != "btrfs" ]]; then
    echo "Error: The root file system is not btrfs as required by aida"
    exit 1
else
    verbose_echo "Info The root file system is btrfs as required by aida"
fi

# Check if the /boot is on same subvolume as root
if [[ -z "$mounted_boot_device_uuid" || -z "$mounted_boot_device_name" || "$mounted_root_subvol_name" != "$mounted_boot_device_name" || "$mounted_root_device_uuid" != "$mounted_boot_device_uuid" ]]; then
    verbose_echo "Info: The /boot folder is on the same subvolume as the / folder as required bu aida"
else
    echo "Error: The / and /boot folder are not on the same btrfs subvolume as required by aida"
    exit 1
fi

# Check if / and /boot/grub are on separate partitions as required by aida
if [[ "$mounted_root_device_uuid" != "$mounted_boot_grub_device_uuid" ]]; then
    verbose_echo "Info: The /boot/grub is on a separate partition as required by aida"
else
    echo "Error: The / and /boot/grub are on not a separete partions as required by aida"
    exit 1
fi

# Check if /var is on separete subvolume or partition
if [[ -z "$mounted_var_device_name" ||"$mounted_root_subvol_name" == "$mounted_var_subvol_name" && "$mounted_root_device_uuid" == "$mounted_var_device_uuid" ]]; then
    echo "Warning: The /var folder is not on a btrfs subvolume, partition, or disk as required by aida"
else
    verbose_echo "Info: The /var folder is on a separate btrfs subvolume, partition, or disk as required by aida"
fi

# Convert snapshot name to human readable datetime
name_to_datetime() {
    local name=$1
    printf '%s-%s-%s %s:%s:%s' \
        "${name:0:4}" \
        "${name:4:2}" \
        "${name:6:2}" \
        "${name:8:2}" \
        "${name:10:2}" \
        "${name:12:2}"
}

# Create the info.xml in /.snapshots/datetime/ for new snapshots
# The info.xml files are currently only used by grub-btrfs
create_info_xml() {
    local updated_from="$1"
    local snapshot_name="$2"
    local target="$snapshot_dir/$snapshot_name/info.xml"
    local datetime="$(name_to_datetime $snapshot_name)"
    echo '<?xml version="1.0"?>' > "$target"
    echo "<snapshot>" >> "$target"
    echo "   <type>single</type>" >> "$target"
    echo "   <num>$snapshot_name</num>" >> "$target"
    echo "   <date>$datetime</date>" >> "$target"
    echo "   <description>Updated from snapshot $updated_from</description>" >> "$target"
    echo "  <cleanup>number</cleanup>" >> "$target"
    echo "</snapshot>" >> "$target"
}

# Update fstab to point to new snapshot - this is no longer needed (the aida-mounts initcpio will take care of mounting mounting the snapshot
#update_snapshot_fstab() {
#    local new_snapshot_name=$1
#    local filename="$aida_mnt_dir/etc/fstab"
#    if [ -z "$(grep /.snapshots/ $filename)" ]; then
#        # No snapshots found in existing fstab of the snapshot
#        sed -i "s|subvol=/@,|subvol=/@snapshots/$new_snapshot_name/snapshot,|" "$filename"
#        # Add an overlay for /etc in fstab for snapshot
#        lower_dir_str="lowerdir=/etc"
#        upper_dir_str="upperdir=/@snapshots/$new_snapshot_name/overlay/etc"
#        work_dir_str="workdir=/@snapshots/$new_snapshot_name/workdir/etc"
#        #systemd_req_str=",x-systemd.requires=/.snapshots.mount" # there is no such thing!
#        overlay_str="overlay /etc overlay noauto,nofail,$lower_dir_str,$upper_dir_str,$work_dir_str 0 0"
#        echo "$overlay_str" >> "$filename"
#    else
#        # Replace references to old snapshot to new snapshot for all occurances in fstab
#        sed -i "s|/@snapshots/[0-9]\{14\}/|/@snapshots/$new_snapshot_name/|g" "$filename"
#    fi
#}

# Create a snapshot from existing snapshot or from current root
create_snapshot_from() {
    # $1 : Name of old snapshot, e.g. "/" or "20261012150123" (must be / or 14 digits datetime)
    local old_snapshot_name="/"
    [[ -n "$1" ]] && old_snapshot_name="$1"
    local old_snapshot_full_name="/"
    [[ "$old_snapshot_name" != "/" ]] && old_snapshot_full_name="$snapshot_dir/$old_snapshot_name/snapshot"
    # Create the new snapshoot in folder datatime of /.snapshots
    local snapshot_name=$(date +%Y%m%d%H%M%S)
    local snapshot_full_name="$snapshot_dir/$snapshot_name/snapshot"
    # Create folders and info.xml for new snapshot
    mkdir -p "$snapshot_dir/$snapshot_name/overlay/etc"
    mkdir -p "$snapshot_dir/$snapshot_name/workdir/etc"
    create_info_xml "$old_snapshot_name" "$snapshot_name"
    # Create btrfs snapshot of currently booted root file system
    btrfs subvolume snapshot "$old_snapshot_full_name" "$snapshot_full_name"
    # Mount new snapshot on working directory
    [[ -n "$(findmnt $aida_mnt_dir)" ]] && umount "$aida_mnt_dir"
    mount --bind "$snapshot_full_name" "$aida_mnt_dir"
#    # Update fstab for the new snapshot # no longer needed
#    update_snapshot_fstab "$snapshot_name" # no longer needed
    # Show content of mounted snapshot:
    verbose_ls "$aida_mnt_dir"
    # Show that a new snapshot was created (even if verbose is off)
    verbose_echo "A new snapshot $snapshot_name was created and mounted on $aida_mnt_dir"
    return 0
}

# Create and mount new snapshot if no snapshout is mounted on /var/aida/mnt
mount_root_subvol() {
  # Check if root subvolume folder is set in config
  if [ -z "$aida_mnt_dir" ]; then
    echo "mount_root_subvol: Internal error in aida framework!"
    exit 1
  fi
  # Ensure that the root subvolume mount point exits
  mkdir -p "$aida_mnt_dir"
  # Create new snapshot and mount it if the mount point is empty, else there is nothing to do becuase a snapshot is already mounted
  if [ -z "$(find $aida_mnt_dir -mindepth 1 -maxdepth 1)" ]; then
    # Create and mount new snapshot
    create_snapshot_from "/"
  else
    # Folder is not empty so the root subvolume is alredy mounted
    verbose_echo "A snapshot is already mount on $aida_mnt_dir"
  fi
  # Show it:
  verbose_ls "$aida_mnt_dir"
}

mount_bind() {
  #echo "$1"
  if [ -z "$1" ]; then
    echo "mount_bind($1): Internal error in aida framework!"
    exit 1
  fi
  if [ -z "$aida_mnt_dir" ]; then
    echo "mount_bind: Internal error in aida framework!"
    exit 1
  fi
  # Check of bind alreay exist
  if [[ -z $(mount | grep "$aida_mnt_dir" | grep "$1 ") ]]; then
    mount --bind "$1" "$aida_mnt_dir$1"
    verbose_echo "Binding successfull $aida_mnt_dir$1"
  else
    verbose_echo "$1 already on $aida_mnt_dir$1"
  fi
}

prepare_chroot() {
  mount_bind "/proc"
  mount_bind "/sys"
  mount_bind "/dev"
  mount_bind "/dev/pts"
  mount_bind "/boot/grub"
  mount_bind "/boot/efi"
  mount_bind "/var"
}

unmount_bind() {
  if [ -z "$1" ]; then
    echo "umount_bind($1): Internal error in aida framework!"
    exit 1
  fi
  if [ -z "$aida_mnt_dir" ]; then
    echo "umount_bind: Internal error in aida framework!"
    exit 1
  fi
  # Unmount the bind if it exists
  if [[ -n $(mount | grep "$aida_mnt_dir" | grep "$1 ") ]]; then
    umount "$aida_mnt_dir$1"
    verbose_echo "Unmounting bind $aida_mnt_dir$1"
  else
    verbose_echo "$1 not mounted on $aida_mnt_dir"
  fi
}
cleanup_chroot() {
  unmount_bind "/proc"
  unmount_bind "/sys"
  unmount_bind "/dev/pts"
  unmount_bind "/dev"
  unmount_bind "/boot/efi"
  unmount_bind "/boot/grub"
  unmount_bind "/var"
}

# This function performs the declarative software update on the root snapshot on the mount point
update_root_subvol() {
  # Check if root subvolume folder is set in config
  if [ -z "$aida_mnt_dir" ]; then
    echo "update_root_subvol: Internal error in aida framework!"
    exit 1
  fi
  # First ensure that the root subvolume is mounted, otherwise create a new snapshot
  mount_root_subvol
  # Mount all bindings for chroot enviroment
  prepare_chroot
  # Do the declarative update
  echo "Starting declarative system update..."
  chroot "$aida_mnt_dir" /usr/bin/bash "$aida_lib_folder/aida-declarative-update.sh"
  echo "Declarative update completed."
  # Unmount all binding for chroot enviroment
  cleanup_chroot
}

# This function allows execution of bash shell commands on root snapshot in chroot
run_chroot_shell_commands() {
  # Check if root subvolume folder is set in config
  if [ -z "$aida_mnt_dir" ]; then
    echo "run_chroot_shell_commands: Internal error in aida framework!"
    exit 1
  fi
  # First ensure that the root subvolume is mounted, otherwise create a new snapshot
  mount_root_subvol
  # Mount all bindings for chroot enviroment
  prepare_chroot
  # Start the interactive shell in chroot
  echo "Opening chroot shell."
  echo "Execute any bash command here to modify the snapshot."
  echo "Type 'exit' to end the interactive shell."
  chroot $aida_mnt_dir /usr/bin/bash "$@"
  echo "Interactive chroot shell closed."
  # Unmount all binding for chroot enviroment
  cleanup_chroot
}

# This function updates the grub menu and umounts the everything
switch_to_new_snapshot() {
  wd="$aida_mnt_dir"
  if [ -z "$aida_mnt_dir" ]; then
    echo "Switch_to_new_snapshot: Internal error in aida framework!"
    exit 1
  fi
  # If the subvolume mount point is empty then there is nothing to switch to, else switch to new snapshot in mount point
  if [ -z "$(find $aida_mnt_dir -mindepth 1 -maxdepth 1)" ]; then
    # Folder is empty so exit with error code 1
    echo "Cannot swich to new snapshot: The $aida_mnt_dir is empty!"
    exit 1
  else
    # Folder is not empty so update grub menu
    # First, mount root subvolume
    mount_root_subvol
    # Then, mount all bindings for chroot environment
    prepare_chroot
    # Then, update the grub menu
    verbose_echo "Updating grub menu..."
    chroot $aida_mnt_dir /usr/bin/grub-mkconfig -o /boot/grub/grub.cfg
    verbose_echo "Grub menu updated"
    # Finally, unmount all bindings for chroot environment
    cleanup_chroot
  fi
  echo "The system is updated. REBOOT NOW PLEASE. Run 'aida-reboot'"
}
