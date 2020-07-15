# LVM features and YaST

The basic LVM functionality has been supported by YaST for ages. But LVM has a lot of features
like RAID, snapshots, thin provisioning and whatsnot that often result in special types of logical
volumes being present in the system.

This document summarizes how the very last version of YaST (that is, the one available in openSUSE
Tumbleweed) deals with systems that contain such advanced LVM setups.

## The Proposal (Guided Setup)

The partitioning proposal will never create logical volumes of any special type beyond normal ones.

In some cases, the proposal may decide to reuse an existing volume group but, even in that case, the
existence of logical volumes of special types will have no negative impact in the proposal since:

- The proposal never reuses existing logical volumes, as proven by [these unit
tests](https://github.com/yast/yast-storage-ng/blob/2315bb6998/test/y2storage/proposal/devices_planner_strategies/ng_test.rb).
- If the proposal decides to delete existing logical volumes, the dependencies between them will
  be honored (see [pull request#1106](https://github.com/yast/yast-storage-ng/pull/1106)).
- When calculating the space available in an existing volume group after each tentative operation,
  the proposal relies on libstorage-ng, which should be able to deal with all kind of LVs.

## The Offline Upgrade Process

Since YaST is able to recognize filesystems on top of any kind of logical volume, it allows to
upgrade any system installed over LVM, including RAID, cache, thin-provisioned volumes, etc.
It even allows to select a snapshot as the system to be upgraded.

## The Partitioner

This section describes how the Expert Partitioner represent the different LVM technologies and what
operations it allows for each type of logical volume.

Note that, unlike RAID0, striped LVs are not really a separate type. Many types of LVs can be
striped.

### Normal LVM

This is somehow the base case. Normal LVs are visualized in the standard way and all operations
are generally supported.

The most noticeable exception is that YaST prevents resizing a logical volume that has snapshots.
It shows "_Resizing not supported since the logical volume has snapshots_".

### Thin Pool and Thin LV

#### How is it displayed?

- Only the thin pool and its thin LVs are displayed. No trace of the hidden LVs used to store the
  data and the metadata of each thin LV or to store the spare metadata of the VG.
- Thin pools and thin LVs are identified as such in the tables. On the other hand, the description
  page of a thin pool or a thin LV looks just like the one of a normal LV.
- In LVM is not possible to define striping for thin LVs, they use the striping defined for their thin
  pools. The partitioner UI reports correctly the number of stripes, **but reports 0.00B for the
  stripes size**.

#### What can be done?

- For thin pools
  - Create: it works.
  - Edit (format/mount): not allowed ("_Is a thin pool. It cannot be edited_").
  - Resize: it works. Thin pools already in disk cannot be shrinked, which is correct.
  - Delete: it works. Note it deletes the pool, all its thin volumes and the associated hidden LVs.

- For thin LVs
  - Create: it works. The widgets for defining striping are disabled and set to the values of the
    corresponding thin pool.
  - Edit (format/mount): just as a normal LV.
  - Resize: it works.
  - Delete: it works. Note it deletes the thin volume and all the associated hidden LVs.

### Cache LV with a Cache Pool

#### How is it displayed?

- Only the cache LV is displayed. No trace of the hidden LVs (origin LV, cache pool, cache data LV
  nor cache metadata LV).
- The cache LVs are identified as such in the tables. On the other hand, the description page of a
  cache LV looks just like the one of a normal LV.

#### What can be done?

- Create: not possible.
- Edit (format/mount): just as a normal LV.
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works. Note it deletes everything: the cache LV, its origin LV, the cache pool, its cache
  data LV and its cache metadata LV.

### Cache LV with a Cache Volume

#### How is it displayed?

- Only the cache LV is displayed. No trace of the hidden cache volume.
- The cache LV is identified as such in the tables but not in its description page, just like the
  previous case.

#### What can be done?

- Create: not possible.
- Edit (format/mount): just as a normal LV.
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works. Note it deletes the cache LV and also its cache volume, as long as the `lvm2`
  package includes the fix for [bsc#1171907](https://bugzilla.suse.com/show_bug.cgi?id=1171907)
  (which is the case for Tumbleweed and for a fully up-to-date SLE 15-SP2).

### Unused Cache Pool

#### How is it displayed?

- Only the cache pool is displayed. No trace of the hidden LVs (cache data LV and cache metadata LV).
- The cache pool is identified as such in the tables but not in its description page, just like the
  previous case.

#### What can be done?

- Create: not possible.
- Edit (format/mount): not allowed ("_Is a cache pool. Cannot be edited_").
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works. Note it deletes also the cache data LV and the cache metadata LV.

### RAID LV

#### How is it displayed?

- Only the RAID LV is displayed. No trace of the so-called subLVs.
- The RAID LVs are identified as such in the tables. On the other hand, the description page of a
  RAID LV looks just like the one of a normal LV.

#### What can be done?

- Create: not possible (not to be confused with the possibility of creating striped LVs).
- Edit (format/mount): just as a normal LV.
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works. Note it deletes also the corresponding subLVs.

### Mirror LVM

#### How is it displayed?

- Only the mirror LV is displayed. No trace of the hidden mirrors used for its images and metadata.
- The mirror LVs are identified as such in the tables. On the other hand, the description page of a
  mirror LV looks just like the one of a normal LV.

#### What can be done?

- Create: not possible.
- Edit (format/mount): just as a normal LV.
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works. Note it deletes also the corresponding hidden LVs.

### Traditional (non-thin) LVM Snapshots

#### How is it displayed?

- The snapshot LV is identified as such in the tables, including the name of its origin LV.
- The description page of any LV that serves as origin contains a list of all its snapshots.
  On the other hand, the description pages of the snapshots look like normal LVs, with no
  reference to the origin LVs.

#### What can be done?

- Create: not possible.
- Edit (format/mount): It's allowed but a warning is displayed beforehand ("_The device is an
  LVM snapshot volume of x. Do you really want to edit it?_").
- Resize: not allowed ("_Resizing of this type of LVM logical volumes is not supported_").
- Delete: it works.
- Delete the origin LV: the corresponding snapshots are deleted right away, since they cannot
  survive their origin. The Partitioner warns beforehand about the snapshots that are going to
  be deleted.

### Thin LVM Snapshots

#### How is it displayed?

- The thin snapshot is identified as such in the tables, including the name of its origin LV.
- The description page of any LV that serves as origin contains a list of all its snapshots,
  including the thin ones. On the other hand, the description pages of the thin snapshots look
  like normal LVs, with no reference to the origin LVs.

#### What can be done?

- Create: not possible.
- Edit (format/mount): It's allowed but a warning is displayed beforehand ("_The device is an
  LVM snapshot volume of x. Do you really want to edit it?_").
- Resize: It works but a warning is displayed beforehand ("_Selected device is an LVM Thin Snapshot.
  Do you really want to resize it?_").
- Delete: it works.
- Delete the origin LV: it works. The snapshots are not affected.

### Writecache LV

Looks like the (open)SUSE `lvm2` package is built without writecache support. That likely means this
type is out of the scope for the time being.

### VDO LVM

Looks like (open)SUSE does not include the VDO kernel module. That likely means this
type is out of the scope for the time being.
