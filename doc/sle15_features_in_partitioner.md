# Expert Partioner: SLE-15-SP1 features

This document is intended to present and discuss some new features that need to be added to the Expert Partitioner. Some of such features are already supported by libstorage-ng but they are not included in the Expert Partitioner yet. The final goal of this document is to decide the best way to add these new features to the Expert Partitioner.

## The problem (the current UI)

The current partitioner UI takes for granted a fixed structure of the storage
devices.

Partitions can be used directly. That is, they can be formatted and mounted,
they can be encrypted, they can be aggregated to construct a RAID or LVM, etc.

Disks are basically containers of partitions, that's their only role. They
cannot be used directly for none of the purposes mentioned above.

RAIDs are always built by combining partitions. A RAID cannot be partitioned.
Each RAIDs is always used directly in a similar way to a partition (that is,
to be formatted/mounted, encrypted, etc.).

LVM VGs (volume groups) are always built by combining partitions. Then they can be
divided into LVM LVs (logical volumes). Each LVM LV is always used directly like
partitions and/or RAIDs.

As such, in the old UI, the purpose of some buttons with generic labels like "Edit"
and "Resize" is defined based on the device they act upon. Since only one
possibility is provided for each device.

For example, when the "Edit" button is pressed for a partition, a RAID or an LVM
LV, it opens the wizard to format/mount/encrypt the device. The only possible
usage considered for them (partitioning a RAID is not considered as such).

But when the "Edit" button is pressed on a disk, it takes the users to the list of
partitions, for they to add/remove/edit partitions from the disk.
Formatting, mounting, or encrypting the disk directly is not considered to be a
possibility.

## The challenge

Now that the users face more scenarios and that our tools support them under the
hood, we need to add more capabilities to the Partitioner. Let's start with
SLE-15-SP1.

The most challenging change we want for SP1 is the ability to combine devices in
a more flexible way. For example, a RAID or LVM can be backed by any combination
of disks and partitions, disks can be formatted and used directly as a whole
(without partitions on it), RAIDs can be partitioned...

For SP1, we also need to add completely new features like BCache.

So we have broken all that into a list of 4 concrete things we need to make
possible for SLE-15-SP1. Each of them is presented in this document together
with some rough ideas.

 * Use full disks (in addition to partitions) to create LVM VGs and RAIDs.
 * BCache
 * Allow to format/mount/encrypt a full disk (just like we do with partitions).
 * Handle partitions within a RAID.

 At the end of the document there is a summary of other features we want to
 contemplate for future releases (SLE-15-SP1, SLE-16... who knows?).

## Feature 1: Use whole disks to create LVM and RAID

In SLE-15-GA, the Expert Partitioner only allows to select plain partitions when creating a LVM Volume Group or a Software RAID. Moreover, only unused partitions with a specific partition id could be selected. But libstorage-ng also allows to create LVM Volume Groups and Software RAIDs based on whole disks. The Expert Partitioner should be able to do it too.

### Proposal 1: Simple Solution

when creating a LVM Volume Group or Software RAID, it should also offer all unused and unpartitioned disks as candidate devices. This would not require any UI change, it is only a matter of offering more candidate devices.

### Proposal 2: Smarter Solution

By default it works as "Simple Solution" describes, but it also adds a checkbox to show all devices, even such devices that are not prepared to be used (e.g., a partition already mounted). If any of these "unprepared" device is selected, a warning should be presented to inform about the actions that will be performed (i.e., remove existing fs, partitions, etc) before use that device for the LVM Volume Group/Software RAID creation.

The advantage is that it should reduce the number of clicks when creating LVM Volume Groups or Software RAIDs. But as disadvantage, the checking for not prepared devices could be tricky and also complex combinations could appear (yet more difficult in already installed systems).

## Feature 2: BCache support

This feature is completely new for both: libstorage-ng and the Expert Partitioner.

BCache technology allows to create software hybrid disks. The idea is to use big rotational disks as persistent storage (backing devices) and then to use a fast (e.g., SSD) device as cache (caching devices) for it. Backing and caching devices could be whole disks or even partitions.

### Research

How it works? BCache has backing and caching devices. It is grouped in sets
( multiple backing and single cache but maybe in future multiple caches will
be possible ) and this set is then registered to bcache device like bcache0
which can be formatted and mounted.

At the end of [this document](https://bcache.evilpiepirate.org/) there is an example. It seems that there is a `/dev/bcacheX` device for each backing device (no sets of backing devices). And a caching device can be use as cache for several backing devices.

For example:

```
make-bcache -B /dev/sdc /dev/sdd -C /dev/sda2
```

* creates `/dev/bcache0` for backing device `/dev/sdd`
* creates `/dev/bcache1` for backing device `/dev/sdc`
* attaches `/dev/sda2` as cache for `/dev/sdd`
* attaches `/dev/sda2` as cache for `/dev/sdc`

Also, it seems that the caching device can be a set of devices, but according to documentation this feature is not supported yet: "Cache devices are managed as sets; multiple caches per set isn't supported yet but will allow for mirroring of metadata and dirty data in the future."

### Open questions

* Could backing devices be grouped in a set (i.e., /dev/bcacheX for several backing devices)?
* Could a caching (or set) be attached to several backing devices at the same time?
* Could a caching device belongs to several sets at the same time?
* Is BCache device partitionable?
* Could a BCache be used for LVM Volume Group or Software RAID creation?

### Proposal: A separate section for BCache

The Expert Partitioner would have a new BCache section (similar to current "Volume Management" or "RAID" ones). It would allow to set multiple BCache devices via wizard that assigns to that device
backing devices and caching devices. See [mockup](mockups/bcache.jpg).

## Feature 3: Format/mount/encrypt whole disks, Partitionable Software RAIDs

Right now the Expert Partitioner allows to format/mount/encrypt Software RAIDs but they cannot be partitioned. And for Disks is just the opposite situation. Disks can be partitioned but they cannot be formatted/mounted/encrypted.

This feature is about adding what is missing in each case. So the Expert Partitioner should allow to format/mount/encrypt whole disks and also it should allow to add partitions to Software RAIDs. All these features are already supported by libstorage-ng.

At the end, Software RAIDs and Disk devices should be almost identical. The only one difference
is that Software RAIDs can be created by the user.

### Proposal 1: add missing buttons everywhere

#### Disks view (named as "Hard Disks")

* Redefine "Edit" button:
  * Right now, when "Edit" is used over a Disk, it simply goes to the Partitions view of the disk to edit its partitions.
  * Instead of that, it should open the dialog to format and set mount point if the selected device can be formatted.

#### RAIDs view

* The wizard launched by "Add RAID" button should not allow to format/set mount point.
* Add button "Add Partition" (similar to Disks view)

#### RAID view (when we are in one specific RAID)

* Add a "Partitions" tab (now it has "Overview" and "Used Devices" tabs)
  * Add "Add", "Edit", "Move", "Resize", "Delete" buttons that act over a partition (similar to "Partitions" tab in "Disk view").
  * Add "Expert" button that allows to "Create Partition Table" and "Clone Disk" (similar to Disks).
* Remove buttons from "Overview" tab
  * "Overview" has three buttons to modify the MD (Edit, Resize, Delete)
  * This actions can be performed in the general "RAIDs view" (similar to Disks).

### Proposal 2: merge "Hard Disks" and "RAID" sections

Disk devices and Software RAIDs are pretty the same. So the idea is to merge both sections. See [mockup](mockups/merge_raids_section.pdf).

* Rename "Hard Disks" section as "Devices"
* Remove section "RAID"

#### Disks view (new "Devices" section)

* Add a "Add RAID" button
* Redefine "Edit" button:
  * It should open the dialog to format and set mount point if the selected device can be formatted.
* Add "Partitions" button
  * This button goes to the "Partitions" tab of a specific device (similar to current "Edit" button when used with a Disk).

#### Disk view (when we are in one specific device)

* When selected device is a MD RAID
  * Add a "Used Devices" tab
  * "Overview" tab should show "Device", "RAID" and "File System" sections

## More features for the future

There are more things in the horizon for the Partitioner that will not make it
to SLE-15-SP1. But still we want to keep them on the radar while making changes
in the UI.

 * Multi-device Btrfs (a Btrfs filesystem can expand through several block devices, combining features of RAID and LVM in that regard).
 * Proper representation of the Btrfs subvolumes (e.g. as a nested list with properties instead of a plain list of paths) in a more discoverable place.
 * RAID: represent and manage spare devices and failed devices (degraded RAID).
 * Wizards/guided workflows to perform steps that now require many steps or to combine the advantages of the Expert Partitioner and the Guided Setup.
