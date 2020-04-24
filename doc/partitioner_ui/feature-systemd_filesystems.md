## Dynamic systemd mount points

This is part of the [bigger document](../partitioner_ui.md) about rethinking the
YaST Partitioner user interface.

In the systemd world, some filesystems are not longer managed simply via `mount` and the
`/etc/fstab` file, like in traditional Unix/Linux systems. Examples of this new way of dynamically
(un)mounting and creating/destroying filesystems:

 * systemd-tmpfiles. See [SLE-11308](https://jira.suse.com/browse/SLE-11308)
 * systemd-gpt-auto-generator. See [bsc#1166512](https://bugzilla.suse.com/show_bug.cgi?id=1166512)
 * systemd-homed. Still not part of (open)SUSE, but something to take into account, just in case.

The way in which systemd manages all this is a whole new concept. If we want to support it properly,
we need to find a way to expose those new concepts in the YaST UI (likely integrated with the
Partitioner somehow) and also in the AutoYaST profiles.
