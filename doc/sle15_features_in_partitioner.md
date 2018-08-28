# SLE15 Features in Partitioner

This document tries to capture possibilities how to allow in partitioner
capabilities that has libstorage-ng in SLE15 and how in the end it is done.

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

* Redefine "Edit" button:
  * It should open the dialog to format and set mount point if the selected device can be formatted.

#### Disk view (when we are in one specific device)

* When selected device is a MD RAID
	* Add "Used Devices" tab
	* "Overview" tab should show "Device", "RAID" and "File System" sections
