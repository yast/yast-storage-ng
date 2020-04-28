## Multiple mount points per device

This is part of the [bigger document](../partitioner_ui.md) about rethinking the YaST Partitioner
user interface.

In Linux, a given filesystem (or Btrfs subvolume) can be mounted at the same moment in several
different paths. The so-called bind mounts has been traditionally used to address several goals,
from setting up jails and chroots to somehow substitute symbolic links in some cases. Recently
they have become more common because they are used by Docker and other container technologies.

It is also possible that the same remote NFS share (same server and same directory) is mounted in
two local directories at the same time.

Up to Leap 15.2, YaST only recognizes one mount point per filesystem. If libstorage-ng (the
underlying library) detects that a device is mounted at several locations, it picks only one mount
point to use (based on some heuristics). That limitation has become a blocker in some situations
(for example, in scenarios with containers), so it has been decided that libstorage-ng will be
adapted to start reporting all the mount points of each filesystem.

That needs to be properly represented in the Partitioner. So far, the mount point is just
represented as a single string visualized in the corresponding column of the tables. The form to
modify the mount point while editing the block device is equaly simple. There is no way to see or
modify the bind mounts for a device.
