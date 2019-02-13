## Bcache

bcache (abbreviated from block cache) is a cache in the Linux kernel's block layer,
which is used for accessing secondary storage devices. It allows one or more
fast storage devices, such as flash-based solid-state drives (SSDs), to act as
a cache for one or more slower storage devices, such as hard disk drives (HDDs);
this effectively creates hybrid volumes and provides performance improvements.

### Limitations in YaST

As its name suggests, in general it can be used on top of any block device. But YaST limits its usage.
YaST does not allow the creation of bcache devices on top of other bcache devices, even indirectly.
Such setup would not make much sense from a practical point of view and it can cause troubles with
the bcache metadata.

Several bcache operations are asynchronous and can take a significant amount of time.
YaST also prevents actions that would trigger such operations. For example, YaST limits
editing or resizing an existing bcache device and removing a bcache device that shares
its caching set. All those actions could imply detaching a cache, which is one of those slow
and asynchronous processes.


### Supported Platforms

Since the SUSE bcache maintainer Coly Li <colyli@suse.com> considers bcache to
be unreliable on architectures other than x86_64, YaST supports bcache only on
that architecture.

On other architectures, the installer and the partitioner will post a warning
if an existing bcache is detected. No bcache operations are offered on those
architectures.


See also

  https://jira.suse.de/browse/SLE-4329?focusedCommentId=918311

