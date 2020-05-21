## Idea: Descriptive Tree View

This is part of the [bigger document](../../partitioner_ui.md) about rethinking the YaST Partitioner
user interface.

This idea consist in improving the current system view (i.e. the one displayed in the screenshot
that illustrates the introduction of this document) to:

- Have a more clear separation between disks and virtual devices like LVM
- Visualize the relationship between disks and partition in a more clear way using some kind of tree
- Display the available free space in every disk or LVM
- Make clearer which parts the user can easily manipulate and which ones are "locked" by system stuff

So the result would look close to this (all neatly arranged in columns; the order of things in the
descriptions is to be discussed, of course):

```
/dev/sda Hitachi 1 TB Disk (GPT)
    /dev/sda1 10 MB BIOS Boot Partition (required)
    /dev/sda2  200 MB EFI System Partition (required)
    /dev/sda3  500 GB Windows Partition NTFS
    /dev/sda4  200 GB Linux Partition Btrfs /
    /dev/sda5  300 GB used by Linux LVM
    free: 0

/dev/sdb Samsung 250 GB SSD
    /dev/sdb1 250 GB used by Linux BCache
    free: 0 
```

As mentioned, virtual devices like LVM, Bcache, etc. would be displayed in a clealy separate section,
likely below the disks. Maybe something similar to this:

```
Linux LVM:
    Encrypted logical volume "system" 200 GB ext4 mounted at /home using VG "lv_system"
    Volume group "lv_system" 300 GB
         Encrypted physical volume /dev/sda5 300 GB

Linux Bcache:
    ... 
```

An important part here is to not get lost in abbreviations like LV, VG, PV; they mean nothing to the
average user, and it's near impossible to Google for them.

The goal of this view is to serve as a starting point to dig deeper into a more detailed level. This is
not meant to switch every little detail immediately; it is the main navigation and orientation tool.
