# YaST and the `_netdev` mount option

For historical reasons, YaST handles the `_netdev` mount option of the mount points. The mechanism
to do it and the criteria to decide whether the option is desirable for a given mount point have
changed over time. This document offers a brief historical summary of the topic.

## Chapter 1

The whole thing originated as [bsc#1047099](https://bugzilla.suse.com/show_bug.cgi?id=1047099) that
was then used as a base to create [bsc#1075529](https://bugzilla.suse.com/show_bug.cgi?id=1075529).
That turned into Fate#325472 and later into
[Fate#325473](https://w3.suse.de/~lpechacek/fate-archive/325473.html).

Finally the discussion in that Fate entry was moved to
[jsc#SLE-7687](https://jira.suse.com/browse/SLE-7687). The conclusion there was that YaST should add
`_netdev` to all mount points based on iSCSI or FCoE disks. A subtask
[jsc#SLE-9191](https://jira.suse.com/browse/SLE-9191) was added to backport that solution to
SLE-15-SP2.

Implemented at [pull request 995](https://github.com/yast/yast-storage-ng/pull/995).

## Chapter 2

A customer reported [bsc#1158536](https://bugzilla.suse.com/show_bug.cgi?id=1158536) which was used
as a base to create [bsc#1165937](https://bugzilla.suse.com/show_bug.cgi?id=1165937).

There it was concluded that the `_netdev` parameter should never be automatically added by YaST to
"_the system root mount or any of the btrfs subvolume mounts that belongs to it_" (almost literal
quote). For non-root mounts, it was concluded it would stay as it was.

Implemented at [pull request 1073](https://github.com/yast/yast-storage-ng/pull/1073).

## Chapter 3

A customer reported [bsc#1176140](https://bugzilla.suse.com/show_bug.cgi?id=1176140) because YaST
was again adding `_netdev` in a situation in which it was not really needed and that prevented the
system from booting. But it was not the root mount point this time.

The conclusions there were that:

- Not all iSCSI or FCoE disks should qualify as remote disks in this context. It was pointed that
  likely the driver was the best way to distinguish whether `_netdev` was applicable to a disk.
- YaST should avoid `_netdev` not only for the root mount and its subvolumes, but also for any
  other mount point based on the same disk than root or, to be more precise, for any mount point
  based on a disk that is initialized by initrd (something that is decided by dracut).
- If a system is using wicked, `/var` must be mounted for the network to be configured. So `/var`
  (and likely other mount points in its same disk) should never get the `_netdev` option.

Since a full-blown fix was impossible for an already released product, the partial fix of filtering
devices by driver was implemented at [pull request
1198](https://github.com/yast/yast-storage-ng/pull/1198).

## Chapter 4

The entry [jsc#PM-2830](https://jira.suse.com/browse/PM-2830) was created to find the best way to
handle the option for SLE-15-SP4 and upcoming versions.

The conclusions there were that:

- The YaST approach should be changed to only add `_netdev` automatically if the Guided Proposal
  is used.
- The criteria for handling `_netdev` should be refined based on the information from chapter 3.

Implemented at [pull request 1254](https://github.com/yast/yast-storage-ng/pull/1254).
