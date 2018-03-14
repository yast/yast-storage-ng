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

Needless to say, when a piece of code can be fully replaced by a storage-ng
equivalent, the old code is simply deleted, not commented.

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

* Assuming `partition.filesystem.mountpoints[0]` is equivalent to the old
  `partition["mount"]`. That's true at the time of writing this, but we need to
  revisit the code after implementing subvolumes in libstorage-ng, just in case.
  `FIXME` added in the relevant part.

* Removed the build dependency from (old) yast2-storage

## Changes in yast2-installation

* Commented the check for destructive disk operations. As a result, when the
  users confirm they want the installation to actually start, the displayed
  popup will not contain the sentence explaining that some partitions will be
  deleted o formatted.

* Commented the code used to remember across executions (self-update) that the
  user canceled multipath activation.

* Commented code in umount_finish.rb dealing with loop files.

* Commented code in prep_shrink.rb that resizes all PReP partitions. I would
  doubt the usefulness of this code at all. Partition sizes are adjusted
  during the proposal. And even *if* we feel like adjusting something we
  would do this only for the partition we actually use for booting.

## Changes in yast2-bootloader

* Code dealing with BIOS-ID changed to assume that boot disk is one which
  have /boot partition.

## Changes in autoyast2

* Commented some parts in `AutoInstallRules` to not use old storage lib (commented
  parts marked with `storage-ng`). This fix problem with install process (see
  [this PBI](https://trello.com/c/qsxBrzIE/499-2-storageng-get-failing-openqa-test-fixed-by-adjusting-autoinstallrules-to-storage-ng)).

* Several tests have been skipped in order to create the package. Commented tests
  need `yast2-installation`, but it is not possible to provide it due to conflict between `yast2-storage` and `yast2-storage-ng`. There is a cyclic dependency between `yast2-installation` and `autoyast2-installation` (see [this bug](https://bugzilla.opensuse.org/show_bug.cgi?id=1024082)).

* Commented several `Yast.import` for the old storage. The affected code is so
  far not adapted to use storage-ng because is not used during a regular
  installation or upgrade.
