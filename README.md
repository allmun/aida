# aida

Atomic Immutable Declarative Archlinux

## Warning

The scripts in this project performs destructive operations on the file system. Major loss of date may result of their use. Systems may become unbootable in case of errors. Do NOT attempt to install aida on an existing production system. Only install aida on systems where data loss and risk of not being able to boot are acceptable. I take no responsibility for any direct or secondary effects.

## What is aida?

The aida project aims at providing a set of bash scrips to transform an arch linux system to provide atomic updates and an immutable root file system with declarative updates for arch based linux system.

The root file system will be immutable by mounting it as a read-only partition during the boot sequency.
Updates to the system is performed on snapshots of the root file system and will never affect a running system.
The changes will only take effect after rebooting the system.

Unlike fedora atomic or opensuse microos, aida does not provide any form of automation except the creation of new snapshots for updates. Deletion of old snapshots must be performed by the user. Aida provides a simple tool 'aida-manager' for doing this easily.

Aida does not delete or mark any failed attempt of updating the software in the snapshots. In case of failed booting, the user must reboot into an old snapshot. After successfull boot, it is recommened to immediately delete the failed snapshot using 'aida-manager'.

Arch linux has a reputation of failing often after updating software. Personally, I have never experiences such problems with pure Arch linux. Pure Arch linux is actually the most stable distrubution I have tried over the last 3 decades. 
However, several times I have experienced that the system went dead after a system update for other distributions derived from Arch. Hopefully, aida can be usefull for such cases.

## Limitations

### Only arch linux

The aida system only work with arch based systems. Other linux variants such as debian or fedora based distributions are not supported. 

#### No AUR

The AUR (Arch User Repository) is not supported by aida. 
Aida only supports the pacman package manager.
It is possible to install AUR packages in the system space using the 'aida-shell', which create a chroot environment in which yay, paru and other package managers can be used.
Aida will not touch such foreign packages during updates, so it's the responsibility of the user to manually perform such updates. 
However, for security reasons, it is discouraged to use AUR packages at the system level.
Instead, it is recommended to only install AUR packages in the user space using e.g. toolbx or distrobox.

## Prerequisites

### File system layout

For aida to work, the file system must be set up accordingly:

* / shall be on a btrfs partion. Aida does not work with any other types of file systems such as ext4 for the root partition.
* /boot shall be on the same partions and subvolume as / for aida to work correcly. /boot shall therefore be an ordinary folder on the / file system.
* /boot/efi   must be on a separate fat32 partition as in most contemporary linux systems. 512 MB is usually enough per system that is installaed.
* /boot/grub  must be on a separate ext4 partition such that updates to grub and and grub-btrfs can be persisted for all snapshots. 
* /home must be on a separate partion or a separate btrfs subvolume.

Other allways-writable folders such as /var will be migrated to separate btrfs subvolumes on the root partition by aida.

Aida will finally create overlays for selected folder on the root file system such that systemd and other system tools can write or update necessary files to the system, e.g. the /etc folder.

## Installing aida

### Install arch linux

Personally, I prefer the Calam-Arch-Installer (https://sourceforge.net/projects/blue-arch-installer/), which makes it very easy to install Arch linux. Ensure that git is installed as part of the system (otherwise, the aida files and folders must be transferred to the system using other methods).

After installation, open a terminal and run the following commands to get a working base configuration:

```
pacman -Qenq > pacman.packages

systemctl list-unit-files --type=service --state=enabled > system.services

systemctl list-unit-files --type=service --state=enabled --user > user.services
```

Inspect the pacman.packages, systen.services, and user.services to verify that they contain a valid configuration (they should not be empty).

### Download aida

Open a terminal and run the following command:

```
git clone https://github.com/allmun/aida.git
```

### Update the configuration

Change to the aida/config directory:

```
cd ./aida/config
```

This directory contains the default pacman.packages, system.services and user.services files.
The default configuration may not be suitable for you.
To overwrite the default files with the files obtained in step 'Install arch linux' run the following commands:

```
cp ../../mypacman.packages ./pacman.packages

cp ../../mysystem.services ./system.services

cp ../../myuser.services ./user.services
```

Notice that aida will remove any package or service that are not declared in the configuration files.

Therefore, after copying, inspect the files in the aida/config folder to ensure that the configuration is valid.

### Start aida installation

Change to the aida/install directory:

```
cd ../config
```

### Initial preparation

Run the following command to check the system and install the required packages and services:

```
sudo bash 1st-boot-initial-prepare.sh
```

Do NOT proceed if this steps fails! 

Reboot the system before proceeding to next step of the installation procedure.

### Prepare system

Run the following command to prepare the system for aida:

```
sudo bash 2nd-boot-prepare-aida.sh
```

This script will transform the file system and create necessary btrfs subvolumes. 

In case of failing this step, the system may become extremely unstable and may not even be able to reboot! 

The system may also become temporarily unstable due to the migration of the /var folder. After restarting the system, it should be stable again. 
Therefore, do not do any unrelated work on the system at this stage but proceed with the installation of aida.

Now, reboot the system before proceeding to next step of the installation procedure. 

Do NOT proceed if the configuration looks invalid or if this step fails.

### Install aida files

Run the following command to install the aida binaries, configuration, and libraries:

```
sudo bash 3rd-boot-install-aida.sh
```

It should be noticed that the aida framework is installed into subfolder of /var/aida. This is a bit unusual for linux systems but it is essentail that aida is available for all snapshots. There are other options for ensuring this, but using /var was chosen for simplicity.

It is adviced to reboot the system before proceeding to the next step.

Do NOT proceed if this steps fails! 

### Create first snapshot

Run the following command to create the first snapshot of the root file system, update the software, and switch to the new snapshot:

```
sudo bash 4th-boot-create-snapshots.sh
```

This script will update the /boot/grub/grub.cfg such that the system will boot into the new snapshot if the default boot option is selected in grub.

### Make system immutable

All the previous steps are performed on the system with an ordinary mutable/writable file system. The final installation step is therefore to make the system immutable, which is achieved by by running the following command:

```
sudo bash 5th-boot-make-immutable.sh
```

Reboot the system to make changes take effect.

Known issue:

The first boot on a new read-only snapshot may experience errors in the boot sequence because the system cannot write to the /etc folder, which initailly is read-only. Later in the boot sequence the /etc writable overlay is mounted such that subsequent writing to /etc can be done without problems. 
It's highly recommended to reboot the system again before using the system for anything else. The second boot seems to go well. It's recommend to run 'journalctl -b' to check the boot log messages and to run 'journalctl -u etc.mount' to check if mounting of the /etc overlay went well. Finally, it is recommended to run 'findmnt' to inspect if / and /etc are mounted in the correct snapshot.

## Future updates to the aida framework

The installation scripts (1st-boot-initial-prepare.sh, 2nd-boot-prepare-aida.sh, 3rd-boot-install-aida.sh, 4th-boot-create-snapshots.sh, and 5th-boot-make-immutable.sh) shall only be executed once!

Attempting to executing these scripts more than once may damange the linux system with potential data loss. The system may also become unbootable.

Therefore, when changes are made to aida, only execute the update script:

```
sudo bash update-installation.sh
```

## Daily use of aida

### Workflow

1) Create new snapshot
2) Modify the configuration
3) Update snapshot
4) Modify snapshots
5) Run shell commands
6) Switch to snapshot
7) Reboot system
8) Or use the aida-manager

### Create new snapshots

The following command will create a new snapshot of the root file system:

```
sudo aida-crate
```

This command will create the snapshot but it will not perform an update or stage it for the next boot.

### Modify configuration

The system configuration can be modified in the snapshop. 
For example, new packages can be added to pacman.packages.

To use your favourite editor, e.g. nano, to edit the eclaration:

```
sudo nano /var/aida/mnt/etc/aida/pacman.packages

sudo nano /var/aida/mnt/etc/aida/system.services

sudo nano /var/aida/mnt/etc/aida/user.services
```

### Update snapshot

The following command will perform a software update of the system using a chroot environment or the snapshot:

```
sudo aida-update
```

This command will update the software but it will not stage the update for the next boot.

It is the responsibility of the user to inspec if the update ran without errors.

### Modify snapshots

Simple changes to snapshots can be done by adding, deleting, and modifying files on a snapshot mounted on /var/aida/mnt. For example, modifying the fstab can be done by running the following command:

```
sudo nano /var/aida/mnt/etc/fstab
```

This requires that a snapshot has been created and mounted on /var/aida/mnt. This can be accomplished by running `aida-create`, `aida-shell`, `aida-update`, or `aida-manager`. After modidying the new snapshot, the command `aida-switch` or the Grub command in `aida-manager` must be used for being able to boot into the new snapshot.

For existing snapshots, it is possbile to make changes without first mounting as desscribed above because all snapshots are mounted on /.snapshots. So, to edit e.g. fstab on snapshot 20261104012732, run the following command:

```
sudo nano /.snapshots/20261104012732/snapshot/etc/fstab
```

However, modifying snapshots directly on /.snapshots/ violates the idea of atomicity and immutability and should therefore be avoided if possible. So, the preferred method is to create a new snapshot and make the modfications on that snapshot as described above.

The methods descibed in this section only applies for simple modification such as adding, removing and updating files. For more elaborate changes, the modification must be performed in a chroot environment by running `aida-shell` as described in th section below.

### Run shell command on snapshot

Aida will allow the user to perform other changes to the system in a chroot environment of snapshot. For example, the user may want to install a package from AUR (not recommended).

To create a new snapshot and start a new chroot enviroment, run the following command:

```
sudo aida-shell
```

Inside the chroot environment, the user can then run e.g.

```
... various commands such as  ...

yay -Syu dirty-compromised-package

... other command and finally ...

exit
```

Working with chroot envirnments can be a bit confusing. Be sure to exit the environment before proceeding.

### Swich to snapshot

After updating the software, the user must stage the snapshot for the next boot. This is done by executing the following command:

```
sudo atomic-switch
```

This command will update the /boot/grub/grub.cfg to point to the new snapshot. 

The user must reboot the system for the changes to take effect.

### Using aida-manager

To manage the system and the snapshots of the root file system , run the following command:

```
sudo aida-manager
```

In this utility, it is possbile to (c) create snapshots, (d) delete snapshots, (u) update snapshots, and updating (g) grub menu (switch to new snapshots).

## Known issues

**001--2026-11-04: Snapshot deletion - Solved 2026-11-04**

With the Delete command in `aida-manager` it is possible to delete snapshots. 
The snapshots are intended to be deleted from /.snapshots. 
However, the overlay and workdir folders can sometimes remain in /.snapshots. 
This issue was fixed by updating the delete command in `aida-manager`.
However, the fix will only remedy future deletions. 
Older incomplete deletions must be cleanup manually by deleting the folders in /.-snapshots.

**002--2026-11-04: Cannot delete stale snapshots - Accepted**

During experimental testing, it has been observed that the /@snapshots contains some snapshot folders containing the info.xml and the overlay and workdir folders but no acutal snapshots which was partially deleted, see issue 2026-11-04-001. The manualy cleanup procedure used in 2026-11-04-001 cannot be used for the @snapshot folder because it is set as read-only, which prevents any form of altering the content of the folder. It should be possible to clean up by (1) creating a new snapshot and set the root file system as writable, (2) reboot  into the new writable snapshot, (3) delete any garbage, (4) create yet another snapshot and set it read-only, (5) boot into the new read-only snapshot, (6) update `aida-manager` and use it to delete the temporary writable snapshot. However this proposed process has not been tested. Typicallay, these stale shapshot folders take up very little data, so it may be acceptable to keep them. 


## Prototype versions

2026-11-04: The prototype has been tested successfully on bare metal. 

2026-11-02: Installation scripts and aida-manager updated with edit functionality

2026-11-01: The prototy has been tested successfully in arch linux in qemu.

2026-10-30: The aim is to have an working alpha release before the end of 2026. 

The aida project is still a prototype and certain parts may not yet work as expectedd. 

## Disclaimer

I do not take any resposibility of using the scripts provided as part of the aida project. I do not guarantee that they will work as intended. I do not guarantee that they will not cause instability or loss of data.
