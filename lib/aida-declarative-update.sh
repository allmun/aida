#!/usr/bin/bash

#MIT License
#Copyright (c) 2026 allmun

set -euo pipefail

# Exit if script is not called with sudo
if [ "$EUID" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# Define configuration directory and files
config_dir="/etc/aida"

# If /etc/aida does not exist, create it as a copy from /var/aida/config
if [ ! -d "$config_dir" ]; then
    mkdir -p "$config_dir"
    cp /var/aida/config/* "$config_dir/"
fi

pkgfile="$config_dir/pacman.packages"

# =======================
# === Pacman Packages ===
# =======================

if ! command -v pacman >/dev/null 2>&1; then
    echo "pacman is not installed or not on PATH." >&2
    exit 1
fi

# Declare lists
declare -A declared_pkgs=()
declare -A installed_pkgs=()
declare -A group_pkgs=()

# Hard-coded addition of packages essential to aida:
declared_pkgs[btrfs-progs]=1
declared_pkgs[grub-btrfs]=1
declared_pkgs[openssh]=1

echo "Reading /etc/aida/pacman.packages declaration file ..."

# Read declared package names. Ignore comments, blanks, and section headings.
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    read -r name _ <<< "$line"

    [[ -z "${name:-}" ]] && continue
    [[ "$name" == *: ]] && continue
    declared_pkgs["$name"]=1
done < "$pkgfile"

echo "Getting list of curently explicitly installed native packages ..."

# Get list of explicitly installed native packages
while read -r name _; do
    [[ -n "${name:-}" ]] && installed_pkgs["$name"]=1
done < <(pacman -Qen)

echo "Getting list of native packages currently installed via group installs ..."

# Get list of packages explicitly installed via groups
while read -r grp pkg _; do
    [[ -n "${pkg:-}" ]] && group_pkgs["$pkg"]="$grp"
done < <(pacman -Qegn)

# Declare lists
pkgs_to_add=()
pkgs_to_remove=()

# Get list of packages to add
for name in "${!declared_pkgs[@]}"; do
    [[ ${installed_pkgs[$name]+yes} ]] || pkgs_to_add+=("$name")
done

# Get list of packagage to remove (ignore packages that are installed as part of groups)
for name in "${!installed[@]}"; do
    # If group_pkgs[name] is defined, get its value, otherwise it's ""
    group="${group_pkgs[$name]+"${group_pkgs[$name]}"}"
    # Skip packages that are installed as part of a declared package
    [[ "$group" != "" && ${declared["$group"]+yes} ]] && continue
    # Remove package if it's not declared or part of a declared group
    [[ ${declared[$name]+yes} ]] || pkgs_to_remove+=("$name")
done


# Remove/uninstall undeclared packages
if (( ${#pkgs_to_remove[@]} )); then
    command pacman -Rns "${pkgs_to_remove[@]}"
fi

# Update all installed packages
command pacman -Syu --noconfirm 2>/dev/null

# Add packages missing declared packages
if (( ${#pkgs_to_add[@]} )); then
    command pacman -S --needed "${pkgs_to_add[@]}"
fi

# Remove/uninstall all orphaned packages
while true; do
    mapfile -t orphans < <(pacman -Qdtq)
    (( ${#orphans[@]} )) || break
    command pacman -Rns --noconfirm "${orphans[@]}"
done

# ===============================
# === SystemD System Services ===
# ===============================

echo ""
echo "Checking systemd system services ..."

sysdfile="$config_dir/system.services"

# Declare lists of system daemons declared and enabled
declare -A declared_sysd=()
declare -A enabled_sysd=()

# Read declared system services. Ignore comments, blanks, and section headings.
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    read -r name _ <<< "$line"
    [[ -z "${name:-}" ]] && continue
    [[ "$name" == *: ]] && continue
    declared_sysd["$name"]=1
done < "$sysdfile"


# Get list of currently enabled system services
while read -r name _; do
    [[ -n "${name:-}" ]] && enabled_sysd["$name"]=1
done < <(systemctl list-unit-files --type=service --state=enabled | awk '$1 ~ /\.service$/ { print $1 }')

# Declare lists of system services to add and remove
sysd_to_add=()
sysd_to_remove=()

# Get list of system services to add
for name in "${!declared_sysd[@]}"; do
    [[ ${enabled_sysd[$name]+yes} ]] || sysd_to_add+=("$name")
done

# Get list of system services to remove
for name in "${!enabled_sysd[@]}"; do
    [[ ${declared_sysd[$name]+yes} ]] || sysd_to_remove+=("$name")
done

# Enable declared system services
if (( ${#sysd_to_add[@]} )); then
    echo "Enabling ${!sysd_to_add[@]}"
    command systemctl enable "${sysd_to_add[@]}"
fi

# Disable undeclared system services
if (( ${#sysd_to_remove[@]} )); then
    while true; do
        echo "Found undeclared but enabled system services: ${sysd_to_remove[@]}"
        read -n 1 -p "System services - Remove, Add to declartion, or temporarily Ignore (r,a,i) " answer
        case $answer in
            [rR]* )
                echo "Removing ${!sysd_to_remove[@]}"
                systemctl disable "${!sysd_to_remove[@]}"
                break ;;
            [aA]* )
                for name in "$sysd_to_remove"; do
                    echo "Adding $name"
                    echo "$name          enabled enabled" >> $sysdfile
                done
                break ;;
            [iI]* )
                echo "Temporarily ignoring services"
                break ;;
            # * ) echo "$1 (y/n) " ;;
        esac
    done
fi

# =============================
# === SystemD User Services ===
# =============================

echo ""
echo "Checking systemd user services ..."

usrdfile="$config_dir/user.services"

# Declare lists of user daemons declared and enabled
declare -A declared_usrd=()
declare -A enabled_usrd=()

# Read declared user services. Ignore comments, blanks, and section headings.
while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line%%#*}"
    read -r name _ <<< "$line"
    [[ -z "${name:-}" ]] && continue
    [[ "$name" == *: ]] && continue
    declared_usrd["$name"]=1
done < "$usrdfile"

# Get list of currnetly enabled user services
while read -r name _; do
    [[ -n "${name:-}" ]] && enabled_usrd["$name"]=1
done < <(systemctl list-unit-files --type=service --state=enabled --user | awk '$1 ~ /\.service$/ { print $1 }')

# Declare lists of user daemons to add and remove
usrd_to_add=()
usrd_to_remove=()

# Get list of user services to add
for name in "${!declared_usrdd[@]}"; do
    [[ ${enabled_usrd[$name]+yes} ]] || usrd_to_add+=("$name")
done

# Get list of user services to remove
for name in "${!enabled_usrd[@]}"; do
    [[ ${declared_usrd[$name]+yes} ]] || usrd_to_remove+=("$name")
done

# Enable declared user services
if (( ${#usrd_to_add[@]} )); then
    echo "Enabling ${usrd_to_add[@]}"
    systemctl enable --user "${usrd_to_add[@]}"
fi

# Disable undeclared user services
if (( ${#usrd_to_remove[@]} )); then
    while true; do
        echo "Found undeclared but enabled user services: ${usrd_to_remove[@]}"
        read -p "User services - Remove, Add to declartion, or temporarily Ignore (r,a,i) " answer
        read -n 1 -p "Remove services, Add services to declartion, or temporarily Ignore these services (r,a,i) " answer
        case $answer in
            [rR]* )
                echo "Disabling ${!usrd_to_remove[@]}"
                systemctl disable --user "${usrd_to_remove[@]}"
                break ;;
            [aA]* )
                for name in "$usrd_to_remove"; do
                    echo "Adding $name"
                    echo "$name          enabled enabled" >> $usrdfile
                done
                break ;;
            [iI]* )
                echo "Temporarily ignoring services"
                break ;;
            # * ) echo "$1 (y/n) " ;;
        esac
    done
fi

echo ""
