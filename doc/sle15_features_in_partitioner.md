# SLE15 Features in Partitioner

This document tries to capture possibilities how to allow in partitioner
capabilities that has libstorage-ng in SLE15 and how in the end it is done.

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

## Full Disks Usage in LVM and RAID

Partioner in SLE15 GA allows to use in LVM and software RAID only partitions
with propoer types. But libstorage-ng allows to use also whole disk as part of
LVM or RAID.

### Simple Solution

Adds as possible device when creating LVM or RAID also disks that do not have
any partition.

### Smarter Solution

When thinking about it, we came to idea that we can have checkbox to show all
devices and when user pick partition or disk that is not ready to be used as
RAID then adapt it. Advantage is that it should reduce number of clicks when
creating arrays or LVMs. Disadvantage is that error checking will become much
more complex, more combination that creates problems and also tricky execution
on running system.

## BCache

Completelly new feature in libstorage-ng that need to be in SLE15 SP1. BCache in
general allows to create software hybrid disks. Where is rotational disk
persistent and fast one like SSD used as cache for it. Slow device can be whole
disk or only partition. Fast device can be also disk or partition.

How it works? Bcache has backing and caching devices. It is grouped in sets
( multiple backing and single cache but maybe in future multiple caches will
be possible ) and this set is then registered to bcache device like bcache0
which can be formatted and mounted.

Open questions:

- is bcache device partitionable?
- can it be used for raid or LVM?

### Separate View for BCache

Having own view for bache like it is already done for LVM and RAID where it
allows to set multiple bache devices via wizard that assign to that device
backing device and cache.

## Format and Mount Whole Disk and Partitionable MD RAID

In libstorage-ng is possible to format and mount whole disks without any
partitions. Also it is possible to have partitions on md RAIDs. This basically
means that RAID device and disk devices is almost identical. Only difference
is that RAID device can be created.

So ideas are how to bring it together. Here is the first proposal:

### Option 1

#### Disks view (named as "Hard Disks")

* Redefine "Edit" button:
  * It should open the dialog to format and set mount point if the selected device can be formatted.

#### RAIDs view

* Wizard lauched by "Add RAID" button should not allow to format/set mount point
* Add button "Add Partition" (similar to Disks view)

#### RAID view (when we are in one specific RAID)

* Add "Partitions" tab (now it has "Overview" and "Used Devices" tabs)
  * Add "Add", "Edit", "Move", "Resize", "Delete" buttons that act over a partition (similar to "Partitions" tab in "Disk view").
  * Add "Expert" button that allows to "Create Partition Table" and "Clone Disk" (similar to Disks).
* Remove buttons from "Overview" tab
  * "Overview" has three buttons to modify the MD (Edit, Resize, Delete)
  * This actions can be performed in the general "RAIDs view" (similar to Disks).

### Option 2

* Rename "Hard Disks" section as "Devices"
* Remove section "RAID"

#### Disks view (new "Devices" section)

* Add "Add RAID" button
* Redefine "Edit" button:
  * It should open the dialog to format and set mount point if the selected device can be formatted.
* Add "Partitions" button
  * This button goes to the "Partitions" tab of a specific device (similar to current "Edit" button when used with a Disk).

#### Disk view (when we are in one specific device)

* When selected device is a MD RAID
  * Add "Used Devices" tab
  * "Overview" tab should show "Device", "RAID" and "File System" sections

## More features for the future

There are more things in the horizon for the Partitioner that will not make it
to SLE-15-SP1. But still we want to keep them on the radar while making changes
in the UI.

 * Multi-device Btrfs (a Btrfs filesystem can expand through several block devices, combining features of RAID and LVM in that regard).
 * Proper representation of the Btrfs subvolumes (e.g. as a nested list with properties instead of a plain list of paths) in a more discoverable place.
 * RAID: represent and manage spare devices and failed devices (degraded RAID).
 * Wizards/guided workflows to perform steps that now require many steps or to combine the advantages of the Expert Partitioner and the Guided Setup.
