## The YaST Partitioner in 15.2

This is part of the [bigger document](../partitioner_ui.md) about rethinking the
YaST Partitioner user interface.

In 15.2 is possible to use the partitioner to manage hard disks,
software-defined RAIDs, LVM, Bcache, NFS and Btrfs (more about this later). In
this context, "hard disk" refers to usual disks, but also to hardware-defined
RAIDs, Multipath devices, DASD and other kinds of not-so-standard devices.

Hard disks, RAIDs and Bcache devices can be used directly as a block device to
hold a filesystem, serve as physical volume for LVM, etc. But they can also
contain partitions instead. In that case, those partitions can be used as block
devices as mentioned (filesystem, PV for LVM, etc.). For example, a RAID can be
composed of full non-partitioned disks or of partitions (or any combination of
both). That RAID can then be formatted directly or broken into its own set of
partitions that are then formatted.

The Partitioner in 15.2 exposes all those possibilities at the same time and at
the same level. As proven by [this discussion](https://lists.opensuse.org/yast-devel/2020-01/msg00014.html),
that leads to navigation difficulties.

Btrfs also deserves to be mentioned here because, unlike it looks at first
sight, it's more than just another filesystem type. First of all, a Btrfs
filesystem can expand through several block devices, combining features of RAID
and LVM in that regard. In addition, a Btrfs filesystem can contain several
subvolumes. Subvolumes are only briefly displayed and managed in the current
YaST Partitioner, but they are the base for implementing several Btrfs features
like snapshots and group quotas.
