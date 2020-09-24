# Expert Partioner: Leap 15.3 and beyond

The interface of the YaST Partitioner has reached a point in which is really hard to deal with it.
It simply has too much functionality and offers too much flexibility out of the box. And we still
want to keep adding more and more storage-related functionality to YaST!

![System view](partitioner_ui/img/system.png)

The goal of this document is to serve as a base to decide how to fix the usability problems in a way
that makes it possible to keep adding functionality.  That's a question we need to solve twice, once
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

## Agreed plan (so far)

This is the main plan to overcome the mentioned challenges and problems. Readers interested in the
result can simply check this section.

To make navigation more understandable we plan to introduce some changes in the layout used by the
Partitioner:

- Use an application menu bar. It would contain global actions that do not really fit in other
  parts of the UI (like rescanning devices) and also all the options that are contextual to the
  device currently selected.
- Simplify the contextual actions that are displayed below each table, showing only plain buttons
  with the most common options, instead of menu-buttons with all possibilities. The less common
  actions would now have to be reached through the menu.
- Use nesting (with the possibility of expanding/collapsing) in the tables to better represent the
  relationship of disks vs partitions, volume groups vs logical volumes, filesystems vs subvolumes,
  etc.
- Create a new Device Overview tab that would be similar for all kind of devices. It should display a
  table with the device itself as first element and all the dependent devices (like partitions of
  the given disk) nested below.
- Limit the nesting in the left tree to display only a first level of devices. Navigating below that
  level will not be possible (eg. there will be no "Device Overview" for an individual partition).
- Show any other information as pop-ups.

With all that, the previous screenshot will turn into something similar to this:

![System view with agreed changes](partitioner_ui/img/system_new.png)

The options that are not longer visible at first sight in that screenshot are moved to the
appropriate menus.

![Menu](partitioner_ui/img/menu_system.png)

Adopting the new table-based Device Overview tab and using pop-ups dialogs when necessary will
result in a more consistent and less confusing interface, with subvolumes management nicely
integrated.

![New Overview Tab](partitioner_ui/img/overview_new.png)

## Other ideas

Section with ideas and concepts that were important during the development of the current plan.
Kept for completeness and for future reference, since we are still considering to incorporate parts
of them to the final implementation.

### Initial ideas

Initial ideas that were originally discussed and leaded to the current plan.

 * [Idea 0: template](partitioner_ui/ideas/template.md)
 * [Idea 1: Small Adjustements](partitioner_ui/ideas/adjustments.md)
 * [Idea 2: Descriptive Tree View](partitioner_ui/ideas/tree.md)
 * [Idea 3: Adaptative Overview Tab](partitioner_ui/ideas/overview.md)
 * [Idea 4: Diagram Driven UI](partitioner_ui/ideas/diagram.md)
 * [Idea 5: All Final Elements in One View](partitioner_ui/ideas/leaf_nodes.md)
 * [Idea 5bis: List of Actions per Device](partitioner_ui/ideas/device_actions.md)
 * [Idea 6: Constrain-based definitions](partitioner_ui/ideas/inventor.md)
 * [Idea 7: Simple Techs Menu and Global Menu Bar](partitioner_ui/ideas/grouped_techs.md)

### Old ideas

This section collects old partial ideas that were discarded or postponed during the development of
the Partitioner in 15.1 or 15.2. Instead of proposing a whole revamp of the interface, they address
concrete topics in the traditional interface.

Listed here for completeness and inspiration. The documents also contain small bits of information
that are useful to understand why some things are implemented in a given way in 15.2.

 * [Merge 'hard disk' and 'RAID' sections](partitioner_ui/ideas/old-merge_sections.md)
 * [Filesystem entry in the tree](partitioner_ui/ideas/old-filesystem_tree_entry.md)
 * [More information when editing a device](partitioner_ui/ideas/old-more_informative_edit.md)
 * [Rethink dialogs to create/edit filesystems](partitioner_ui/ideas/old-different_edit.md)
