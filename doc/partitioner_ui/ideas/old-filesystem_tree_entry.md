## The "File Systems" tree entry

This is part of the [bigger document](../../partitioner_ui.md) about rethinking the YaST Partitioner
user interface.

During the development of 15.2, it was considered (but discarded) to replace the "Btrfs" entry in
the left tree with a "File Systems" entry that would contain a list with all the filesystems,
including the multi-device Btrfs ones but also any other traditional filesystem of any type.

This would be the only view in which the traditional filesystems (backed by only one block device)
would be visible as an entity on their own, instead of just some kind of property of the underlying
block device.

This option was discarded because it would add too much duplication to the left tree and to the
partitioner in general with no clear gain. The only case in which this extra section would be useful
to do something that cannot be currently done would be with Btrfs filesystems.
