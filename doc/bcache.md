## Bcache

bcache (abbreviated from block cache) is a cache in the Linux kernel's block layer,
which is used for accessing secondary storage devices. It allows one or more
fast storage devices, such as flash-based solid-state drives (SSDs), to act as
a cache for one or more slower storage devices, such as hard disk drives (HDDs);
this effectively creates hybrid volumes and provides performance improvements.

### Limitations in YaST

As name suggest in general it can be used on top of any block device. But YaST limits its usage.
YaST does not allow recursive bcache devices, even indirect. So bcache on top of bcache is
prevented. The reason is that it does not make much sense and can cause trouble with metadata.

Also due to bcache asynchronous operations that can took significant amount of time, YaST limits
operation that take so much time. It include e.g. detaching of cache which limits e.g. resize of
bcache device, edit of existing bcache or remove bcache that shares caching set.
