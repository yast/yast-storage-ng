# Installer hacks

This document describes the shortcut that had been taken in order to make sure
the installer runs with libstorage-ng and yast2-storage-ng.

For every YaST module that has needed adaptation, a `storage-ng` branch has been
created in the corresponding repository. This document should always contain a
summary of the changes in those branches, in a human-readable fashion.

## Changes in yast2-country

* Commented the check for Windows partitions. As a result of that change,
  `Timezone.windows_partition` is always false, so the installer does not
  assume the internal clock to be set to local time.

## Changes in yast2-network

* Commented the code used to check if the root path (/) is in a network device,
  i.e. installation on top of NFS. As a result, the `nfsroot` mode is never
  activated.

## Changes in yast2-installation

* Commented the code that searches for autoinst.xml in a floppy disk.

* Commented the check for destructive disk operations. As a result, when the
  users confirm they want the installation to actually start, the displayed
  popup will not contain the sentence explaining that some partitions will be
  deleted o formatted.
