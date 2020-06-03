# LVM features and YaST

The basic LVM functionality has been supported by YaST for ages. But LVM has a lot of features
like RAID, snapshots, thin provisioning and whatsnot that often result in special types of logical
volumes being present in the system.

This document summarizes how well YaST deals with systems that contain such advanced LVM setups.

## The Partitioner

This section describes how the Expert Partitioner represent the different LVM technologies and what
operations it allows for each type of logical volume. At the current stage, some operations show an
unexpected behavior and, in most cases, would need to be adjusted. That is represented in bold text.

Note that, unlike RAID0, stripped LVs are not really a separate type. Many types of LVs can be
stripped.

### Normal LVM

This is somehow the base case. Normal LVs are visualized in the standard way and all operations
are generally supported.

The most noticeable exception is that YaST prevents resizing a logical volume that has snapshots and
is active. It shows "_Resizing not supported since the logical volume has snapshots_".

### Thin Pool and Thin LV

#### How is it displayed?

- Only the thin pool and its thin LVs are displayed. No trace of the hidden LVs used to store the
  data and the metadata of each thin LV or to store the spare metadata of the VG.
- Due to a bug, **nothing in the UI identifies the displayed LVs as being special**. They basically
  look like normal LVs, although `BlkDevicesTable::DEVICE_LABELS` contains entries for both thin
  pools and thin LVs.
- In LVM is not possible to define stripping for thin LVs, they use the stripping defined for their thin
  pools. The partitioner UI **reports 0 stripes for all thin LVs**.

#### What can be done?

- For thin pools
  - Create: it works.
  - Edit (format/mount): not allowed ("_Is a thin pool. It cannot be edited_").
  - Resize: it works. Thin pools already in disk cannot be shrinked, which is correct.
  - Delete: it works. Note it deletes the pool, all its thin volumes and the associated hidden LVs.

- For thin LVs
  - Create: it works. The **widgets for defining stripping are disabled and set to the default values**.
    Maybe it would be better to show them disabled but with the pool values. Or to not show them at all.
  - Edit (format/mount): just as a normal LV.
  - Resize: it works.
  - Delete: it works. Note it deletes the thin volume and all the associated hidden LVs.

### Cache LV with a Cache Pool

#### How is it displayed?

- Only the cache LV is displayed. No trace of the hidden LVs (origin LV, cache pool, cache data LV
  nor cache metadata LV).
- **Nothing in the UI identifies the cache LV as being so**, it basically looks like a normal LV
  (eg. there is no entry for cache LV at `BlkDevicesTable::DEVICE_LABELS`)

#### What can be done?

- Create: not possible.
- Edit (format/mount): just as a normal LV.
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works. Note it deletes everything: the cache LV, its origin LV, the cache pool, its cache
  data LV and its cache metadata LV.

### Cache LV with a Cache Volume

#### How is it displayed?

- Only the cache LV is displayed. No trace of the hidden cache volume.
- **Nothing in the UI identifies the cache LV as being so**, just like the previous case.

#### What can be done?

- Create: not possible.
- Edit (format/mount): just as a normal LV.
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works. It only deletes the cache LV, the LV used as cache survives (it becomes a
  normal LV) **but is not visible immediately**. A reprobing after the commit phase is needed.
  The root cause is an inconsistent behavior of `lvremove` compared to other cases, reported
  as [bsc#1171907](https://bugzilla.suse.com/show_bug.cgi?id=1171907).

### Unused Cache Pool

#### How is it displayed?

- Only the cache pool is displayed. No trace of the hidden LVs (cache data LV and cache metadata LV).
- **Nothing in the UI identifies the cache pool as being so**, just like the previous cases.

#### What can be done?

- Create: not possible.
- Edit (format/mount): not allowed ("_Is a cache pool. Cannot be edited_").
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works. Note it deletes also the cache data LV and the cache metadata LV.

### RAID LV

#### How is it displayed?

- Only the RAID LV is displayed. No trace of the so-called subLVs.
- **Nothing in the UI identifies the RAID LV as being so**, it basically looks like a normal LV
  (eg. there is no entry for the RAID types at `BlkDevicesTable::DEVICE_LABELS`)

#### What can be done?

- Create: not possible (not to be confused with the possibility of creating stripped LVs).
- Edit (format/mount): just as a normal LV.
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works. Note it deletes also the corresponding subLVs.

### Mirror LVM

#### How is it displayed?

- Only the mirror LV is displayed. No trace of the hidden mirrors used for its images and metadata.
- **Nothing in the UI identifies the mirror LV as being so**, it basically looks like a normal LV
  (eg. there is no entry for the RAID types at `BlkDevicesTable::DEVICE_LABELS`)

#### What can be done?

- Create: not possible.
- Edit (format/mount): just as a normal LV.
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works. Note it deletes also the corresponding hidden LVs.

### Traditional (non-thin) LVM Snapshots

#### How is it displayed?

- The snapshot LV is displayed as a normal LV. **Nothing in the UI says its type is `snapshot`**
  (eg. there is no entry for snapshots at `BlkDevicesTable::DEVICE_LABELS`).
- There is **no information in the UI about the relationship with its origin** LV.

#### What can be done?

- Create: not possible.
- Edit (format/mount): **just as a normal LV**. May not be strictly wrong but is weird at least.
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works.
- Delete the origin LV: the corresponding snapshots are deleted during the commit phase, but
  **not immediately in the devicegraph in memory**. Moreover, the Partitioner **does not warn**
  about the snapshots that are going to be deleted.

### Thin LVM Snapshots

#### How is it displayed?

- The snapshot LV **is displayed in the UI as a normal LV**, although it's type in the devicegraph
  is `thin-pool`. That's due to a bug already commented in the section about thin provisioning.
- There is **no information in the UI about the relationship with its origin** LV.

#### What can be done?

- Create: not possible.
- Edit (format/mount): **just as a normal LV**. May not be strictly wrong but is weird at least.
- Resize: **it works** since this is just a thin LV. Again, maybe not wrong but weird.
- Delete: it works.
- Delete the origin LV: it works. The snapshots are not affected.

### Writecache LV

Looks like the (open)SUSE `lvm2` package is built without writecache support. That likely means this
type is out of the scope for the time being.

### VDO LVM

Looks like (open)SUSE does not include the VDO kernel module. That likely means this
type is out of the scope for the time being.
