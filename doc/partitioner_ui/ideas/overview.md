## Idea: Adaptative Overview Tab

This is part of the [bigger document](../../partitioner_ui.md) about rethinking the YaST Partitioner
user interface.

When clicking in a device, the Partitioner has traditionally presented a tabbed interface in which
the first tab is always the so-called "Overview" that presents all kind of technical details about
the device. The relationship with other devices is then presented in separate tabs like
"Partitions", "Logical Volumes", "Physical Volumes", "Used Devices", etc. With all the possibilities
currently offered by the Partitioner, it's usually not so obvious which of those tabs is the most
useful one for each device.

This idea proposes to present always the same two tabs for all devices.

 - A first one called "Overview" offering the possible actions. Its content would change based on
   the content of the device.
 - A second "Details" tab that would contain all the technical details that are currently presented
   in the "Overview" one, but without any action button.

It would be possible to add more informative tabs (maybe one to display the actions that will be
executed for the device), but the main point is that only the "Overview" tab should contain buttons
to perform actions.

### Overview Tab for an Empty Disk

```
   Hard Disk: /dev/sda
   ┌Overview──Details ───────────────────────────────┐
   │                                                 │
   │Size: 500.00 GiB - Model: HGST HTS75000          │
   │The device is empty                              │
   │                                                 │
   │ - Create a file system directly in the disk     │
   │   [Format/mount]                                │
   │                                                 │
   │ - Partition the disk                            │
   │   [New partition table] [Add Partition]         │
   │                                                 │
   │                                                 │
   │                                                 │
   │                                                 │
   └─────────────────────────────────────────────────┘
```

### Overview Tab for a Disk with a Partition Table

```
   Hard Disk: /dev/sda
   ┌Overview──Details ───────────────────────────────┐
   │Size: 500.00 GiB - Model: HGST HTS75000          │
   │Partition table: GPT             [Add Partition] │
   │┌───────────────────────────────────────────────┐│
   ││Device   │      Size│F│Enc│Type          │Label││
   ││/dev/sda1│100.00 GiB│ │   │NTFS Partition│windo││
   ││/dev/sda2│400.00 GiB│ │   │NTFS Partition│recov││
   ││                                               ││
   ││                                               ││
   │└├────────────────────────┤─────────────────────┘│
   │          [Format/Mount] [Resize] [Move] [Delete]│
   │                                                 │
   │More options for the disk:                       │
   │ [Clone partitions]  [Wipe content]              │
   └─────────────────────────────────────────────────┘
```

### Overview Tab for a Disk with a File System

```
   Hard Disk: /dev/sda
   ┌Overview──Details ───────────────────────────────┐
   │                                                 │
   │Size: 500.00 GiB - Model: HGST HTS75000          │
   │The device contains a Btrfs file system.         │
   │Mounted at /                                     │
   │                                                 │
   │ - Modify the file system                        │
   │   [Format/mount] [Subvolumes]                   │
   │                                                 │
   │ - Remove the current file system                │
   │   [Wipe device content] [New partition table]   │
   │                                                 │
   │                                                 │
   │                                                 │
   └─────────────────────────────────────────────────┘
```

### Overview Tab for a Disk Being Used as Physical Volume

```
   Hard Disk: /dev/sda
   ┌Overview──Details ───────────────────────────────┐
   │                                                 │
   │Size: 500.00 GiB - Model: HGST HTS75000          │
   │The device is part of the LVM /dev/system        │
   │                                                 │
   │No actions can be performed directly in          │
   │the disk                                         │
   │                                                 │
   │                                                 │
   │                                                 │
   │                                                 │
   │                                                 │
   │                                                 │
   │                                                 │
   └─────────────────────────────────────────────────┘
```

Or maybe it would be possible to offer options there to detach the disk from the volume group or to
delete the volume group. Or to offer the same options that are offered for an empty device, just
deleting the VG as a consequence of those actions (with a warning pop-up, of course).

### Overview Tab for an Empty RAID

```
   RAID: /dev/md0
   ┌Overview──Details ───────────────────────────────┐
   │                                                 │
   │Size: 500.00 GiB - RAID1 [Used Devices]          │
   │The device is empty                              │
   │                                                 │
   │ - Create a file system directly in the RAID     │
   │   [Format/mount]                                │
   │                                                 │
   │ - Partition the RAID                            │
   │   [New partition table] [Add Partition]         │
   │                                                 │
   │ - Remove the RAID                               │
   │   [Delete]                                      │
   │                                                 │
   └─────────────────────────────────────────────────┘
```

### Overview Tab for a RAID with a Partition Table

```
   RAID: /dev/md0
   ┌Overview──Details ───────────────────────────────┐
   │Size: 500.00 GiB - RAID1 [Used Devices]          │
   │Partition table: GPT              [Add Partition]│
   │┌───────────────────────────────────────────────┐│
   ││Device   │      Size│F│Enc│Type          │Label││
   ││/dev/sda1│100.00 GiB│ │   │NTFS Partition│windo││
   ││/dev/sda2│400.00 GiB│ │   │NTFS Partition│recov││
   ││                                               ││
   ││                                               ││
   │└├────────────────────────┤─────────────────────┘│
   │          [Format/Mount] [Resize] [Move] [Delete]│
   │                                                 │
   │More options for the RAID:                       │
   │ [Clone partitions]  [Wipe content]  [Delete]    │
   └─────────────────────────────────────────────────┘
```

### Overview Tab for a RAID with a File System

```
   RAID: /dev/md0
   ┌Overview──Details ───────────────────────────────┐
   │Size: 500.00 GiB - RAID1 [Used Devices]          │
   │The device contains a Btrfs file system.         │
   │Mounted at /                                     │
   │                                                 │
   │ - Modify the file system                        │
   │   [Format/mount] [Subvolumes]                   │
   │                                                 │
   │ - Remove the current file system                │
   │   [Wipe device content] [New partition table]   │
   │                                                 │
   │ - Remove the RAID                               │
   │   [Delete]                                      │
   └─────────────────────────────────────────────────┘
```

### Overview Tab for an LVM Volume Group

```
   LVM Volume Group: /dev/vg0
   ┌Overview──Details ───────────────────────────────┐
   │Size: 1.00 GiB                                   │
   │Logical volumes:             [Add Logical Volume]│
   │┌───────────────────────────────────────────────┐│
   ││Device       │      Size│F│Enc│Type    │Label│M││   
   ││/dev/vg0/home│500.00 GiB│ │   │Ext4 LV │     │/││   
   ││/dev/vg0/root│ 30.00 GiB│ │   │BtrFS LV│     │/││
   ││                                               ││
   ││                                               ││
   │└├────────────────────────┤─────────────────────┘│
   │                 [Format/Mount] [Resize] [Delete]│
   │                                                 │
   │More options for the volume group:               │
   │ [Physical Volumes]  [Delete]                    │
   └─────────────────────────────────────────────────┘
```
