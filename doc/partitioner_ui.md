# Expert Partioner: Leap 15.3 and beyond

The interface of the YaST Partitioner has reached a point in which is really hard to deal with it.
It simply has too much functionality and offers too much flexibility out of the box. And we still
want to keep adding more and more storage-related functionality to YaST!

![System view](partitioner_ui/img/system.png)

The goal of this document is to serve as a base to decide how to fix the usability problems in a way
that makes possible to keep adding functionality.  That's a question we need to solve twice, once
for SLE-15-SP3 (Leap 15.3) and again for the next major release (ie. SLE-16 / Leap 16.0). Why twice?
On one hand for the obvious time restrictions, if we design a completely new concept it could be not
fully ready in time for 15.3, while targetting 16.0 gives us more room to be ambitious and creative.
On the other hand, because SLE service packs (Leap minor versions) are not expected to introduce
disruptive changes.

Can't a single solution target both 15.3 and 16.0? Sure it can, if we come up with something that
can be implemented in the needed time-frame, that does not imply loosing functionality, and that is
compatible/similar enough.

The scope of the discussion should be to define a new interface for the Expert Partitioner or to
define some kind of complementary/auxiliary tool for it. That does not include other parts of YaST
related to storage management (like the so-called Guided Setup).

## Challenges and problems

### Keep the functionality

Listing here all the features of the Partitioner available in Leap 15.2 would probably make little
sense. But a reminder about the general functionality may be relevant. See this [small
summary](partitioner_ui/functionality.md).

### Add new functionalities

Apart from all the possibilities in the summary linked above, we would like to add the following
functionalities to YaST. Some of them in the very short term and others as a long-term plan (likely
after 15.3). In that regard, the list is sorted in some kind of chronological order according to the
plans at the time of writing this document.

 * Proper representation of the Btrfs subvolumes and support for group quotas.
   [Read more](partitioner_ui/feature-subvolumes.md).
 * Play nicely with filesystems and mount points dynamically managed by systemd.
   [Read more](partitioner_ui/feature-systemd_filesystems.md).
 * Support multiple mount points per device.
   [Read more](partitioner_ui/feature-multiple_mount_points.md).
 * Wizards/guided workflows to perform steps that now require many steps or to combine the
   advantages of the Expert Partitioner and the Guided Setup.
 * More comprehensive support for RAID, like representing and managing to some extent spare devices
   and failed devices (degraded RAID).

### Text mode interface

One of the killer features of YaST is its ability to represent almost the same interface in
graphical and text mode. In order to be considered acceptable, all YaST interfaces must be fully
functional in a text console with 80 columns and 24 lines.

![System view in text mode](partitioner_ui/img/system-ncurses.png)

## Ideas

Possible plans to overcome the mentioned challenges and problems:

 * [Idea 0: template](partitioner_ui/idea-template.md)

## Old ideas

This section collects old partial ideas that were discarded or postponed during the development of
the Partitioner in 15.1 or 15.2. Instead of proposing a whole revamp of the interface, they address
concrete topics in the traditional interface.

Listed here for completeness and inspiration. The documents also contain small bits of information
that are useful to understand why some things are implemented in a given way in 15.2.

 * [Merge 'hard disk' and 'RAID' sections](partitioner_ui/idea-merge_sections.md)
 * [Filesystem entry in the tree](partitioner_ui/idea-filesystem_tree_entry.md)
 * [More information when editing a device](partitioner_ui/idea-more_informative_edit.md)
 * [Rethink dialogs to create/edit filesystems](partitioner_ui/idea-different_edit.md)
