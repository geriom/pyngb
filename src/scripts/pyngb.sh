#!/bin/bash

# This thing was inspired by this article:
# http://www.mikerubel.org/computers/rsync_snapshots/
# ----------------------------------------------------------------------
# mikes handy rotating-filesystem-snapshot utility
# ----------------------------------------------------------------------

unset PATH  # suggestion from H. Milz: avoid accidental use of $PATH

# ------------- system commands used by this script --------------------
# --I should automate this, with a makefile probably--
ID=/usr/bin/id;
ECHO=/bin/echo;

MOUNT=/bin/mount;
RM=/bin/rm;
MV=/bin/mv;
CP=/bin/cp;
TOUCH=/bin/touch;

RSYNC=/usr/bin/rsync;


# ------------- file locations -----------------------------------------
# --Read this off a config file--
# to do: What if the config file changes?. think about this 

MOUNT_DEVICE=/dev/sdc1; # Device
SNAPSHOT_RW=/root/backup; # Mounting point

# Let's automatically check if every folder has a ".backupignore" file
# And probably parse some regex too
EXCLUDES=/home/geri/Soft/backups_system/backup_exclude;  

# List of directories to backgup. Read these from a config file
# Remeber to make it robust in case the dummy user deletes the file
MY_HOME=/home/geri;


# ------------- the script itself --------------------------------------

# make sure we're running as root
if (( `$ID -u` != 0 )); then { $ECHO "Sorry, must be root.  Exiting..."; exit; } fi

# attempt to remount the RW mount point as RW; else abort
$MOUNT -o remount,rw $MOUNT_DEVICE $SNAPSHOT_RW ;
if (( $? )); then
{
  $ECHO "snapshot: could not remount $SNAPSHOT_RW readwrite";
  exit;
}
fi;


# rotating snapshots of $MY_HOME (fixme: this should be more general)

# step 1: delete the oldest snapshot, if it exists:
if [ -d $SNAPSHOT_RW$MY_HOME/daily.3 ] ; then     \
$RM -rf $SNAPSHOT_RW$MY_HOME/daily.3 ;        \
fi ;

# step 2: shift the middle snapshots(s) back by one, if they exist
if [ -d $SNAPSHOT_RW$MY_HOME/daily.2 ] ; then     \
$MV $SNAPSHOT_RW$MY_HOME/daily.2 $SNAPSHOT_RW$MY_HOME/daily.3 ; \
fi;
if [ -d $SNAPSHOT_RW$MY_HOME/daily.1 ] ; then     \
$MV $SNAPSHOT_RW$MY_HOME/daily.1 $SNAPSHOT_RW$MY_HOME/daily.2 ; \
fi;

# step 3: make a hard-link-only (except for dirs) copy of the latest snapshot,
# if that exists
if [ -d $SNAPSHOT_RW$MY_HOME/daily.0 ] ; then     \
$CP -al $SNAPSHOT_RW$MY_HOME/daily.0 $SNAPSHOT_RW$MY_HOME/daily.1 ; \
fi;

# step 4: rsync from the system into the latest snapshot (notice that
# rsync behaves like cp --remove-destination by default, so the destination
# is unlinked first.  If it were not so, this would copy over the other
# snapshot(s) too!
$RSYNC                \
  -va --delete --delete-excluded        \
  --exclude-from="$EXCLUDES"        \
  $MY_HOME/ $SNAPSHOT_RW$MY_HOME/daily.0 ;

# step 5: update the mtime of daily.0 to reflect the snapshot time
$TOUCH $SNAPSHOT_RW$MY_HOME/daily.0 ;

# and thats it for home.

# now remount the RW snapshot mountpoint as readonly

$MOUNT -o remount,ro $MOUNT_DEVICE $SNAPSHOT_RW ;
if (( $? )); then
{
  $ECHO "snapshot: could not remount $SNAPSHOT_RW readonly";
  exit;
} fi;
