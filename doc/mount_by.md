# Managing the mount_by attributes

## Management of mount_by in the library

There are two kinds of devices with an attribute called mount_by. Although they
have different meanings, both are usually initialized to the same default value.
A simple mechanism is offered by libstorage-ng to set that global default
value. In that regard, the library is agnostic from the architecture or any
other criteria traditionally used to select the default mount_by.

The two mount_by attributes are the following.

* `MountPoint#get_mount_by` defines the way the `mount` command identifies the
  filesystem (or subvolume) to mount. In other words, it defines the form of the
  first field in the `fstab` file. `MountPoint` contains a couple of methods to
  set the mount_by.

  * `#set_default_mount_by` is used internally when creating a new mount point
    with `Mountable#create_mount_point`. It relies on
    `Mountable#get_default_mount_point` which almost always just returns the
    global default mount_by. The only two exceptions that always return `DEVICE`
    are NFS filesystems and filesystems directly on top of an LVM LV.

  * `#set_mount_by` is meant to be used by the library user (i.e. YaST) and is
    also used during probing.

* `Encryption#get_mount_by` defines the form of the second field in the
  `crypttab` file. Encryption contains the equivalent couple of methods to set
  the mount_by.

  * `#set_default_mount_by` is used when creating a new device with
    `BlkDevice#create_encryption`. It always sets the value to the global
    default.

  * `#set_mount_by` is also meant to be used by the library user and during
    probing.

The exact meaning of each possible value (DEVICE, UUID, LABEL, ID and PATH)
depends on the context. Check the Yardoc documentation of
`Y2Storage::MountPoint#mount_by` and `Y2Storage::Encryption#mount_by` for more
details.

The library does not prevent its user (i.e. YaST) from setting a mount_by which
doesn't make sense for the device, neither in `MountPoint` or in `Encryption`.
Instead of that, senseless values are just ignored, falling back to using the
device name, when calculating the actions in the corresponding implementation of
`#get_mount_by_name` on each class. See `BlkFilesystemImpl#get_mount_by_name` as
an example for the `MountPoint` mechanism and `EncryptionImpl#get_mount_by_name`
as an example of the equivalent mechanism for the `crypttab` file.

The library offers `MountPoint#possible_mount_bys` which returns a set of
possible values based on the type of the filesystem and of its block device. But
"possible" doesn't necessarily means correct. This method doesn't check if the
mount_by is consistent with other aspects of the device being formatted. For
example, it includes `LABEL` even if the filesystem doesn't specify a label,
since such label could be configured at some later point before the commit
phase.

There is no equivalent `Encryption#possible_mount_bys` to know the set of
possible values to use in `crypttab`.

## Management of mount_by in yast2-storage-ng

Currently, the global default mount_by comes from `Y2Storage::Configuration`
and its initial value per architecture is set at [src/fillup](../src/fillup/).
So YaST (and not the library) is responsible for setting the global default
based on the content of `/etc/sysconfig/storage` and for allowing the user to
change that global value using the Partitioner.

YaST needs to ensure a reasonable (or, at least, acceptable) value for both
mount_by attributes. The libstorage-ng behavior of almost blindly assigning the
global default value to everything may be problematic.

Moreover, in the Partitioner only the mount methods that are really suitable for
each case must be presented to the users when they click on "Fstab Options".
Relying on the mentioned `MountPoint#possible_mount_bys` is clearly not enough.

That's why `Y2Storage` implements the concept of "suitable mount_by", which is
used at several points to minimize the possibilities of triggering the
libstorage-ng fallback to DEVICE (which is only executed during the commit
phase) and to minimize some risks related to the usage of encryption with
volatile keys.

On the other hand, `Y2Storage` also includes some mechanisms to keep the
consistency of the mount_by attributes of a Btrfs filesystem and its subvolumes.
Every time the attribute is changed for a filesystem or when a new subvolume is
created, the corresponding method (`Btrfs#copy_mount_by_to_subvolumes` or
`BtrfsSubvolume#copy_mount_by_from_filesystem`) is called internally.
