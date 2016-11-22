# Installer hacks

This document describes the shortcut that had been taken in order to make sure
the installer runs with libstorage-ng and yast2-storage-ng.

For every YaST module that has needed adaptation, a `storage-ng` branch has been
created in the corresponding repository. This document should always contain a
summary of the changes in those branches, in a human-readable fashion.

## Changes in yast2-network

* Commented the code used to check if the root path (/) is in a network device,
  i.e. installation on top of NFS. As a result, the `nfsroot` mode is never
  activated and `STARTMODE` is not set to "nfsroot" in the corresponding
  `ifcfg-xx` file of the installed system.

* Removed the dependency from (old) yast2-storage

## Changes in yast2-packager

* Commented the unit tests of SpaceCalculation because SpaceCalculation, like
  many other parts of yast2-packager that rely on StorageWrapper, do not work
  properly if `Yast::Storage` is not present.

* Removed the build dependency from (old) yast2-storage

## Changes in yast2-installation

* Commented the code that searches for floppy drives during system analysis.

* Commented the code that searches for autoinst.xml in a floppy disk.

* Commented the check for destructive disk operations. As a result, when the
  users confirm they want the installation to actually start, the displayed
  popup will not contain the sentence explaining that some partitions will be
  deleted o formatted.

* No more usage of StorageController, the module that loads additional drivers
  for technologies like RAID or multipath. As soon as we introduce support for
  such technologies we will need an object-oriented replacement. Or maybe it's
  not needed anymore if udev does that job now.

* Commented the code that reads files from previous installations right after
  hard drives probing. It affects importing of previous ssh keys and users.

* Commented the code used to remember across executions (self-update) that the
  user canceled multipath activation.

* Commented code in umount_finish.rb dealing with loop files.

## Changes in yast2-bootloader

* Testsuite disabled.

* Various code dealing with RAID, alternative device names and crypt devices
  disabled. All marked with "# storage-ng".

* Code dealing with BIOS-ID changed to blindly assume common values. Original
  code commented and marked with "storage-ng".
