## Idea: Simple Techs Menu and Global Menu Bar

This is part of the [bigger document](../../partitioner_ui.md) about rethinking the YaST Partitioner
user interface.

This is a less disruptive idea. Its main goal is to rearrange the content to make it easier to find and understand.

The current layout is composed only by a tree on the left side and the rest of the content on the right. I see some troubles with this approach.

The left tree is very complex. It contains quite a lot of information and it is easy to get lost when there are several devices and several technologies taking place in the current system configuration. Moreover, it mixes several purposes. On one hand, it can be used as a devices browser tool and, on the other hand, it serves as a menu bar (think about some options like *Settings*, *Devices Graphs* or *Installation Summary*).

The view on the right side sometimes contains general options like *Rescan Devices* or the options for configuring *iSCSI* or *FCOE* devices. After being playing a while with the Partitioner, it is easy to forget where that general options were placed, and most likely you would need several clicks until find them again.

And apart of all that, the landing point of the Partitioner shows a table containing absolutely all the devices. This is too much information for a starting point.

This idea proposes to include a real menu bar and a simple menu on the left to categorize each storage technology.

### Simple Techs Menu

A simple menu of tech categories would replace the current tree on the left:

```
   ┌─────────────────┐─────────────────────────────────────────────┐
   │ System Overview │                                             │
   │─────────────────┐                                             │
   │ Hard Disks (2)  │                                             │
   │─────────────────┐                                             │
   │ LVM (3)         │                                             │
   │─────────────────┐                                             │
   │ RAID (0)        │                                             │
   │─────────────────┐                                             │
   │ Bcache (1)      │                                             │
   │─────────────────┐                                             │
   │ Btfs (1)        │                                             │
   │─────────────────┐                                             │
   │ NFS (0)         │                                             │
   │─────────────────┐                                             │
   │ USB (1)         │                                             │
   └─────────────────┘─────────────────────────────────────────────┘
```

Each section in the menu contains a number between brackets to indicate the current amount of devices belonging to that technology. At a simple glance you can deduce how your system is configured without going to low details. Moreover, the landing page would be the *System Overview* section, where only the relevant final devices are presented. For example, in a typical installation with LVM, *System Overview* would contain a table with these devices (basically, it only shows the mounted devices):

```
   ┌─────────────────┐──────────────────────────────────────────────────────┐
   │ System Overview │                                                      │
   │─────────────────┐ ┌───────────────────────────────────────────────────┐│
   │                 │ │Device       │      Size│F│Enc│Type    │Label│Mount││
   │─────────────────┐ │/dev/vg0/home│500.00 GiB│ │   │Ext4 LV │     │/home││
   │                 │ │/dev/vg0/root│ 30.00 GiB│ │   │BtrFS LV│     │/root││
   │─────────────────┐ │                                                   ││
   │                 │ └├────────────────────────┤─────────────────────────┘│
   │                                                                        │
   │                                                                        │
   │                                                                        │
   │                                                                        │
   └─────────────────┘──────────────────────────────────────────────────────┘
```

This menu could have some dynamic sections. For example, the *USB* section only makes sense to appear if there are USB devices in the system.


### Global Menu Bar

The application layout would contain a new Global Menu Bar on the top. This would be a typical menu bar with the generic options that the user can use at any moment.

```
   ┌──────────────┐─────────────┐─────────────┐────────────┐───────┐   < Global Menu Bar
   └──────────────┘─────────────┘─────────────┘────────────┘───────┘
   ┌─────────────────┐─────────────────────────────────────────────┐
   │ System Overview │                                             │
   │─────────────────┐                                             │
   │ Hard Disks (2)  │                                             │
   │─────────────────┐                                             │
   │ LVM (3)         │                                             │
   │─────────────────┐                                             │
   │ RAID (0)        │                                             │
   │─────────────────┐                                             │
   │ Bcache (1)      │                                             │
   │─────────────────┐                                             │
   │ Btfs (1)        │                                             │
   │─────────────────┐                                             │
   │ NFS (0)         │                                             │
   │─────────────────┐                                             │
   │ USB (1)         │                                             │
   └─────────────────┘─────────────────────────────────────────────┘
```

The options for this Menu Bar could be something like:

* Partitioner
   * Apply Changes
   * Quit

* Edit
   * Preferences

* Devices
   * Visual Graph
   * Rescan

* Config
   * Provide Crypt Passwords
   * iSCASI Devices
   * FCoE Devices

* Summary

* Help

All those options already exist in the Expert Partitoner. Some of them are placed in the tree view and others are in the general system view. Having them all together in the same menu bar would help to find them at any moment.

### Including the Adaptative Overview Tab idea

When we go to a specific device, for example by selecting *LVM* in the left menu and then selecting a specific Logical Volume from the table, maybe it would make sense to follow an approach as the proposed in [Adaptative Overview Tab](../../ideas/overview.md) idea.
