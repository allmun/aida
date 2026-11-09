# aida

Atomic Immutable Declarative Archlinux

## Latest news

2026-11-09: Major redesign of installation process. Now, only two scripts (separated by a system reboot) are needed for installating aida. Also, mounting of  snapshots and the /etc overlays has been streamlined using initcpio hooks. 

## Roadmap

The following updates to the aida-manager is planned:

- add m (Mounting) functionality to aida-manager ---status: todo
- add s (Shell) functionality to aida-manager ---status: todo
- add f (full update = clone/update/grub-switch) functionality to aida-manager ---status: todo
- remove clear screen from print table function? ---status: todo
- refactor code to string input instead of char input: get command from `${string:0:1}` and numbers from `${s:2}` ---status: todo
- refactor code to preapare for CLI mode (only run loop if no arguments provided) ---status: todo

After implementing the above updates to aida-manager, the aida-create, aida-shell, aida-switch, and aida-update may be depricated (to be decided).

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
It is possible to install AUR packages in the system space using the 'aida-shell', which create a chroot environment in which yay, paru and other package managers can be used. Aida will not touch such foreign packages during updates, so it's the responsibility of the user to manually perform such updates. 
However, for security reasons, it is discouraged to use AUR packages at the system level. Instead, it is recommended to only install AUR packages in the user space using e.g. toolbx or distrobox.

## Prerequisites

### File system layout

For aida to work, the file system must be set up accordingly:

* / shall be on a btrfs partion. Aida does not work with any other types of file systems such as ext4 for the root partition.
* /boot shall be on the same partions and subvolume as / for aida to work correcly. /boot shall therefore be an ordinary folder on the / file system.
* /boot/efi   must be on a separate fat32 partition as in most contemporary linux systems. 512 MB is usually enough per installed system.
* /boot/grub  must be on a separate ext4 partition such that updates to grub and and grub-btrfs can be persisted for all snapshots. 512 MB should be enough.
* /home must be on a separate partion or a separate btrfs subvolume.

Other allways-writable folders such as /var and /.snapshots will be migrated to separate btrfs subvolumes on the root partition by aida.

Aida will finally create overlays for selected folder on the root file system such that systemd and other system tools can write or update necessary files to the system, e.g. the /etc folder.

### Init systems

Aida only support **systemd** based distributions. 

Aida uses **mkinitcpio** for generating the initial ramdisk environment for booting the Linux kernel  that allows automatic mounting of /.snapshots, /etc, and / during the early boot phases. Other systems for generating initramfs such as 'dracut'  are not supported. 

## Installing aida

### Install arch linux

The Calam-Arch-Installer (https://sourceforge.net/projects/blue-arch-installer/) makes it very easy to install Arch linux in few guided steps. Another option is to use the official arch installer (https://archlinux.org/download/). Other arch based distributions such as CrashyOS, Garuda, Manjaro, Omarchy, etc have not been tested with aida. 

Ensure that the file system layout is set up as described above.

Ensure that git is installed as part of the system (otherwise, the aida files and folders must be transferred to the system using other methods).

### Download aida

Open a terminal and run the following commands:

```
git clone https://github.com/allmun/aida.git

cd aida/install
```

### Prepare and setup

Run the following command to check the system, create essential folders, install the required packages and services, and migrate folders to btrfs subvolumes:

```
sudo bash 1st-prepare-and-setup.sh
```

This script will transform the file system and create necessary btrfs subvolumes. 

In case of failing this step, the system may become unstable and may not even be able to resart! The system may also become temporarily unstable due to the migration of the /var folder. After restarting the system, it should be stable again. Therefore, do not do any unrelated work on the system at this stage but proceed with the installation of aida as described below.

Do NOT proceed if the configuration looks invalid or if this step fails.

Reboot the system before proceeding to next step of the installation procedure.

### Create snapshot and set immutable

Run the following command to create the first snapshot and set the system immutable:

```
sudo bash 2nd-migrate-and-set-immutable.sh
```

This script creates the first snapshot, updates the software packages and servicies according to the latest configuration. The script also install the initcpio hooks to automatically mount the snapshot and overlays during the early boot phases. The script finally updates the grub boot menu such that the new snapshot will be the default boot choice.

Reboot the system for the changes to take effect.

## Using aida

### Workflow

After installing aida, the system can only be updated in new snapshots. The following workflow process must be used for modifying or updating the system:

1) Create new snapshot
2) Modify the configuration
3) Update snapshot
4) Modify snapshots
5) Run shell commands
6) Switch to snapshot
7) Reboot system
8) Or use the aida-manager

Step 1 creates a writable snapshot for that can be used for updating the system. Step 2 is used for adding, changing, or deleting software packages, systemd system and user services . Steps 3 is used for updating the system to the latest declaration. Step 4 can be used for modifying files in the snapshot. Step 5 can be used for performing chroot shell commands, e.g. adding or removing software packages using yay, paru, etc. Step 6 is used for setting the new snapshot as the default boot choice in the grub boot menu. Step 7 is used for letting the changes take effect. In step 8, the user can use the `aida-manager` to perform step 1,2,3, and 6 (steps 4, 5, and 7 are currently not implemted in aida-manager).

### Create new snapshots

The following command will create a new snapshot of the root file system:

```
sudo aida-crate
```

This command will create the snapshot but it will not perform an update or stage it for the next boot.

Alternatively, the `c` (clone) command in the `aida-manager` can be used for creating a new snapshots from any of the existing snapshots.

### Modify configuration

The system configuration can be modified in the snapshop. 
For example, new packages can be added to pacman.packages.

To use your favourite editor, e.g. nano, to edit the eclaration:

```
sudo nano /var/aida/mnt/etc/aida/pacman.packages

sudo nano /var/aida/mnt/etc/aida/system.services

sudo nano /var/aida/mnt/etc/aida/user.services
```

The above commands require that a snapshot is mounted on /var/aida/mnt.

Alternatively, the `e` (edit) command in the `aida-manager` can be used for editing the declarative configuration for any existing snapshot.

### Update snapshot

The following command will perform a software update of the system using a chroot environment or the snapshot:

```
sudo aida-update
```

This command will update the software but it will not stage the update for the next boot. It is the responsibility of the user to inspect if the update ran without errors.

Alternatively, the `u` (update) command in the `aida-manager` can be used for updating the software packages and services for any existing snapshot.

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

Alternatively, the `g` (grub) command in the `aida-manager` can be used for switching to any existing snapshot.

### Using aida-manager

To manage the system and the snapshots of the root file system , run the following command:

```
sudo aida-manager
```

In this utility, it is possbile to q (quit), c (clone/copy snapshots), d (delete snapshots), u (update snapshots), g (switch to snapshot by updating the grub boot menu), and e (edit the declation files) 

#### Examples of using the aida-manager

Below is shown an example of how the `aida-manager` can be used. In the example, the used has booted into snapshot 20261108090511 and created a clone 20261109130024. The user is then about to run a system update on the cloned snapshot by ussuing the `u 1` command:

```
#     Date and Time          Root  Grub  Mount Name                
------------------------------------------------------------
1     2026-11-09 13:00:24                M     20261109130024      
2     2026-11-08 09:05:11    R     G           20261108090511      
3     2026-11-07 22:55:24                      20261107225524      
4     2026-11-05 20:37:59                      20261105203759      
5     2026-11-04 19:30:27                      20261104193027      
6     2026-11-04 12:55:28                      20261104125528      

Cloning snapshot: 1

Actions: q (quit), c (clone), d (delete), u (update), g (grub) e (edit): u 1   
```

After running the update commands, the user then ussues the `g 1` command for updating the grub menu::

```
#     Date and Time          Root  Grub  Mount Name                
------------------------------------------------------------
1     2026-11-09 13:00:24                M     20261109130024      
2     2026-11-08 09:05:11    R     G           20261108090511      
3     2026-11-07 22:55:24                      20261107225524      
4     2026-11-05 20:37:59                      20261105203759      
5     2026-11-04 19:30:27                      20261104193027      
6     2026-11-04 12:55:28                      20261104125528      

Updated snapshot 20261109130024 (2026-11-09 13:00:24)

Actions: q (quit), c (clone), d (delete), u (update), g (grub) e (edit): g 1     
```

After updating the grub menu, the user decides to some delete old snapshots:

```
#     Date and Time          Root  Grub  Mount Name                
------------------------------------------------------------
1     2026-11-09 13:00:24          G     M     20261109130024      
2     2026-11-08 09:05:11    R                 20261108090511      
3     2026-11-07 22:55:24                      20261107225524      
4     2026-11-05 20:37:59                      20261105203759      
5     2026-11-04 19:30:27                      20261104193027      
6     2026-11-04 12:55:28                      20261104125528      

Reboot to activate grub snapshot 20261109130024

Swithced to snapshot 20261109130024 (2026-11-09 13:00:24)

Actions: q (quit), c (clone), d (delete), u (update), g (grub) e (edit): d 4,5-6
```

The user is asked to confirm deletions of each snapshot:

```
Actions: q (quit), c (clone), d (delete), u (update), g (grub) e (edit): d 4,5-6    
Delete snapshot 4 (20261105203759) [y/n]y
Delete snapshot 5 (20261104193027) [y/n]y
Delete snapshot 6 (20261104125528) [y/n]
```

After deletion, the following snapshots and status are shown in aida-manager:

```
#     Date and Time          Root  Grub  Mount Name                
------------------------------------------------------------
1     2026-11-09 13:00:24          G     M     20261109130024      
2     2026-11-08 09:05:11    R                 20261108090511      
3     2026-11-07 22:55:24                      20261107225524      

Reboot to activate grub snapshot 20261109130024

Deleted snapshot(s): 20261105203759 20261104193027 20261104125528

Actions: q (quit), c (clone), d (delete), u (update), g (grub) e (edit): 
```

The user must q (quit)  aida-manager and reboot the system for the changes in the new snapshot to take effect (the deleted snapshot are gone forever and cannot be restored).

## Known issues

Installation script 1st-prepare-and-setup.sh seems to not add the correct systemd services to the declarative configuration. The user will be asked to r (remove), a (add), or i (ignore) the services during the system update. The user should take action a (add) to ensure that the required services are added to the declaration config files.

## Prototype versions

2026-11-09: Major changes to the installation scripts implemented and tested in qemu. 

2026-11-04: The prototype has been tested successfully on bare metal. 

2026-11-02: Installation scripts and aida-manager updated with edit functionality

2026-11-01: The prototy has been tested successfully in arch linux in qemu.

2026-10-30: The aim is to have an working alpha release before the end of 2026. 

The aida project is still a prototype and certain parts may not yet work as expectedd. 

## Disclaimer

I do not take any resposibility of using the scripts provided as part of the aida project. I do not guarantee that they will work as intended. I do not guarantee that they will not cause instability or loss of data.
