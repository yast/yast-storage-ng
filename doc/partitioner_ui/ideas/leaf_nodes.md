## Idea: All Final Elements in One View

This is part of the [bigger document](../../partitioner_ui.md) about rethinking the YaST Partitioner
user interface.

The idea presentend in this section is actually in an early stage and have several known drawbacks,
but it aims to foster the consideration of different approaches when looking into the problem. With
such approach, sections like "hard disk", "LVM", "RAID", etc. would not longer be the main way to
interact with the Partitioner. Their functionality will remain somewhere, maybe slightly hidden
compared to the current status.

Instead, the main entry point will be a list of the devices (or free spaces) that are currently
usable. Let's see it with an example.

Imagine a system with sda containing two Windows partitions, sdb containing a small partition and a
partially used LVM and sdc completely empty. In the classic Partitioner we would navigate through a
tree containing all this:

```
Hard disks
  - sda
    - sda1
    - sda2
  - sdb
    - sdb1
    - sdb2
  - sdc
RAID
Volume Management
  - vg0
    - root
    - home
Bcache
```

But for such setup, the list proposes in this idea (it's still undefined whether it would be the
first section of the left tree or something completely different) would contain something like this:

```
sda1 (NTFS)
sda2 (NTFS)
sdb1 (ext3)
vg0/root (btrfs)
vg0/home (ext4)
Free space at vg0
sdc (empty)
```

Those are the devices (or spaces) that can be used for something immediately.

That is, `sda` is not displayed because is fully used, so there is not much the users can do with it
unless they delete/resize its partitions first. `sdb2` is not displayed because it's the physical
volume of `vg0`, so the users likely don't want to do anything with it, unless they destroy `vg0`
first. And so on.

In that list, if the users select `sda1` they could then decide to mount it or reformat it. And of
course, they could also decide to delete or resize it, which will result in a new free space
appearing in the list.

If they select the free space in `vg0`, they would have the option to create a new logical volume.

If they select `sdc`, they would be able to format it or to create a partition table on it. Maybe
even the option to use it as physical volume for an existing or new volume group.

In short, the main point is to get a curated list of devices that the user likely wants to modify
in the next action and to offer the applicable/reasonable options for each of them.

### Drawbacks

The new view would be convenient to create small adjustments in the storage layout, but would be
rather useless for big changes like using a whole disk to create a new setup from scratch. The users
would have to manually deconstruct the whole (potentially complicated) structure level by level and
step by step.

In addition, there would be many situations in which the disks themselves (like `sda`, `sdb` and
`sdc` in the example) would not be present in that initial list. That's counterintuitive since disks
are the primary handle for users to make sense of the whole picture, because it corresponds to
something from the real physical world.


