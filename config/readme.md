# Configuration files

The configuration files will first be copied to /var/aida/config by the 3rd installation scripts. After the copying, the files in the aida git config folder will no longer be used. 

Later, the configuration files will be copied from /var/aida/config to /var/aida/mnt/etc/aida when a snapshot is created  and mounted  by e.g. the 4th installation script. After the copying to the snapshop, the files in /var/aida/config will no longer be used.

So to update the configuration, the following steps must be executed:

1) Create a new snapshot and mount it on /var/aida/mnt
   This can be by using the Clone command in aida-manager

3) Edit the configuration files the following location:
   /var/aida/mnt/etc/aida
   This can be done by using the Edit commands in aida-manager


