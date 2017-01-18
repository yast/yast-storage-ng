# Installer hacks

This document describes the shortcut that had been taken in order to make sure
the installer runs with libstorage-ng and yast2-storage-ng.

For every YaST module that has needed adaptation, a `storage-ng` branch has been
created in the corresponding repository. This document should always contain a
summary of the changes in those branches, in a human-readable fashion.

## Temporarily commented code

To easily identify the code that has been commented in the adapted repositories
temporarily (waiting for storage-ng to provide the needed functionality)
block comments with the following format are used.

```ruby
  # storage-ng
  value = 0
=begin
  something = Storage.Something()
  value = Storage.Value(something)
=end
```

In the example, `value = 0` is new temporary code needed to avoid other errors
(usually variable initializations to some sensible default). That code is not
always necessary, but if it's present it should be between the "storage-ng"
comment and the beginning of the block comment.

If the temporary code is not needed, the result will look like this.

```ruby
# storage-ng
=begin
  Storage.Something()
=end
```

Notice that block comments are used even when one single line is commented.

Needles to say, when a piece of code can be fully replaced by a storage-ng
equivalent, the old code is simply deleted, not commented.

## Changes in yast2-network

* Commented the code used to check if the root path (/) is in a network device,
  i.e. installation on top of NFS. As a result, the `nfsroot` mode is never
  activated and `STARTMODE` is not set to "nfsroot" in the corresponding
  `ifcfg-xx` file of the installed system.

* Removed the dependency from (old) yast2-storage

## Changes in yast2-packager

* Commented some code dealing with NFS and encrypted volumes in
  `SpaceCalculation`. Corresponding unit tests disabled (marked with `skip`).

* Simplified the code checking the journal size in a JFS filesystem. JFS is not
  supported anymore, so now the code simply assumes the default JFS journal size
  is used in all JFS filesystems.

* Commented the code checking the reserved space in a filesystem that is going
  to be created. Libstorage-ng simply provides `Filesystem#mkfs_options`. It's
  up to yast2-storage to store something meaningful there while defining the
  filesystem. So far that is not done, so there is no information about the
  space that will be reserved.

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

* Disabled some unit tests dealing with non-supported features (see below).

* Various code dealing with RAID, alternative device names and crypt devices
  disabled. All marked with "# storage-ng".

* Code dealing with BIOS-ID changed to blindly assume common values. Original
  code commented and marked with "storage-ng".
