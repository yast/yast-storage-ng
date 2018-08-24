## Partitioner checks

An overview of checks done by the (old) partitioner when run in the installed system and some thoughts about checks
that might be useful in storage-ng.

### Checks in old storage code with source code references

- [custom_part_lib.rb\#L43](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_lib.rb#L43)

    - (LVM not for /boot): "You cannot use the mount point \"%1\" for LVM."

- [custom_part_lib.rb\#L64](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_lib.rb#L64)

    - (RAID not for /boot, with exceptions): "You cannot use the mount point %1 for RAID."

- [custom_part_lib.rb\#L91](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_lib.rb#L91)

    - "You have selected to not automatically mount at start-up a file system that may contain files that the system needs to work properly."

- [custom_part_lib.rb\#L131](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_lib.rb#L131)

    - "You have set a file system as mountable by users. The file system may contain files that need to be executable." 

- [custom_part_lib.rb\#L1052](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_lib.rb#L1052)

    - "It is not possible to shrink the file system while it is mounted."

- [custom_part_lib.rb\#L1065](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_lib.rb#L1065)

    - "It is not possible to extend the file system while it is mounted."

- [custom_part_lib.rb\#L1078](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_lib.rb#L1078)

    - "It is not possible to resize the file system while it is mounted."

- [ep-dialogs.rb\#L1223](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/ep-dialogs.rb#L1223)

    - "You are extending a mounted filesystem by %1 Gigabyte. This may be quite slow and can take hours. You might possibly want to consider umounting the filesystem, which will increase speed of resize task a lot."

- [ep-dialogs.rb\#L960](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/ep-dialogs.rb#L960)

    - "Partition %1 cannot be resized because the filesystem seems to be inconsistent."

- [ep-dialogs.rb\#L947](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/ep-dialogs.rb#L947)

    - "It is not possible to check whether a NTFS can be resized while it is mounted."

- [custom_part_lib.rb\#L212](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_lib.rb#L212)

    - "FAT filesystem used for system mount point (/, /usr, /opt, /var, /home). This is not possible."

- [custom_part_lib.rb\#L233](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_lib.rb#L233)

    - "You cannot use any of the following mount points: /bin, /dev, /etc, /lib, /lib64, /lost+found, /mnt, /proc, /sbin, /sys, /var/adm/mnt"

- [custom_part_lib.rb\#L248](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_lib.rb#L248)

    - "It is not allowed to assign the mount point swap to a device without a swap file system."

- [custom_part_check_generated.rb\#L259](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_check_generated.rb#L259)

    - "You tried to mount a FAT partition to one of the following mount  points: /, /usr, /home, /opt or /var. This will very likely cause problems."

- [custom_part_check_generated.rb\#L272](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_check_generated.rb#L272)

    - "You tried to mount a FAT partition to the mount point /boot. This will very likely cause problems."

- [custom_part_check_generated.rb\#L285](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_check_generated.rb#L285)

    - "You have mounted a partition with Btrfs to the "mount point /boot. This will very likely cause problems."

- [custom_part_check_generated.rb\#L414](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_check_generated.rb#L414)

    - "Warning: Some subvolumes of the root filesystem are shadowed by mount points of other filesystem."

- [custom_part_check_generated.rb\#L685](https://github.com/yast/yast-storage/blob/SLE-12-SP4/src/include/partitioning/custom_part_check_generated.rb#L685)

    - "It cannot be deleted while mounted."

### Other checks

- there are warnings in the old storage code about (then) required things, like

    - /boot
    - position of /boot (< 1024 cylinders)
    - /boot is on RAID
    - vfat EFI system partition
    - swap partition missing

> ok/missing/? - status in storage-ng

- [ok] do not remove root
- [missing] do not format root
- [missing] do not change root mount point (e.g. from / to /tmp)
- [?] do not resize root (if it implies to unmount)
- [?] do not (indirectly) remove root:

    - remove a device that forces to remove a VG where root is placed
    - remove a device that forces to remove a MD where root is placed

### Some thoughts

- There are a number of explicit checks in the old partitioner that deal with device dependencies (like removing a partition
that belongs to some RAID). These work (AFAICS) automatically in storage-ng.

- [maybe?] do not remove btrfs subvolumes on root (old storage code shows it red in the summary but does not expicitly warn, new storage code indicates nothing)

- How to recover from incomplete commits (if e.g. unmounting of some volume fails)?
