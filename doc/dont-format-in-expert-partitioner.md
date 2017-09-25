# Implementing 'do not format' in the expert partitioner

## About this document

This should be a short-lived document just to explain a difference in behavior
introduced in the expert partitioner by storage-ng when compared to the old
storage stack. The current API and philosophy of `libstorage-ng` and the expert
partitioner make it impossible to keep the traditional behavior. This document
describes why and sketches a possible solution. After fixing the problem
(hopefully sooner than later) this document will become obsolete and should be
deleted.

Additionally, another problematic situation is presented at the end of the
document. Although it affects a completely different part of the expert
partitioner it could be fixed with basically the same proposed approach.

## The problem

When editing a partition (the same applies to any other block device that can
hold a filesystem), the expert partitioner displays a form with two options:
"format partition" and "do not format partition". Now imagine the following
situation.

* Everything starts with `/dev/sda2` containing an ext2 filesystem
* (Step 1) The user edits this partition and select to format it as ext4
* (Step 2) The user then performs several other actions in other partitions
* (Step 3) The user opens again the edit form for `/dev/sda2`, selects "do
  not format partition" and clicks "next"

The result should be that the original ext2 filesystem is back in the general
view and applying the changes with the partitioner should not alter it or
destroy it.

With the current implementation of the storage-ng partitioner, which performs
the changes in a devicegraph in memory, that cannot be implemented because it
would imply copying (or restoring, to be precise) a device from the system
devicegraph to the working devicegraph without copying the whole devicegraph,
something that is currently no possible.

## The obvious solution

The problem can be fixed with a new functionality in the libstorage-ng API and
some work in the expert partitioner. The library should allow to copy a device
to another devicegraph keeping the `sid` and all its attributes. Then the expert
partitioner could use that and some common sense to really restore the original
filesystem while not breaking anything else in the devicegraph. Not rocket
science, but not something to program in 10 minutes.

## The alternatives/workarounds

### The second 'edit' cleanups the filesystem

The result with the current implementation is that after the third step
`/dev/sda2` will look empty, with no filesystem. That is, the "do not format"
option turns into "leave unformatted" when entering edit for the second time.
It only changes from the behavior point of view, the label still says "do not
format partition".

This was the chosen alternative, despite being quite inconsistent from the user
point of view, because all other scenarios work exactly like in the old
partitioner except the one explained about, which is relatively hard to reach.

### Consider the current devicegraph as the one to respect

This is another alternative that would have been more consistent but too
different to the old one and rather confusing during installation. In short,
when clicking in 'edit', the user would be modifying the current state of
`/dev/sda2` as displayed in the expert partitioner, not its state in the disk.

From that point of view, selecting "do not format partition" would not mean
respecting the original ext2 filesystem, but the _current_ ext4 one. In other
words, the "do not format" option would mean "do not change what is
configured now". Changing that without actually changing the label is confusing.
Using the expert partitioner to modify the proposal makes everything even more
confusing, since "do not format" means "do what the proposal suggested".

### Others

Some other behaviors were tested or considered, but the result was usually
tricky in one way or another and is not worth describing them all here.

## More problems

When creating an MD RAID in the expert partitioner, the user can select the
partitions to add by just choosing them from a list of available devices. In
the same screen, the user can interactively change the RAID level (mirroring,
striping, etc.). When any of these things are changed, the size of the resulting
MD array displayed in the UI is dinamically updated.

Following the new partitioner phylosophy, the partitions are immediately added to
or removed from the MD device libstorage-ng object when the user (de)select them,
so the UI can directly rely on the logic in the storage-ng object to report the
size. Unfortunately, adding the partitions to the MD array changes some
attributes of that partition and removes all its current descendants in the
devicegraph, like any possible file-system or LUKS device. If the user decides
then to move the partition out of the definitive list, that partition would have
been already harmed even if it ends up not being used.

The problem can be fixed without needing to rethink the whole expert partitioner
functionality and without having to duplicate logic. Just by adding to
libstorage-ng the mechanism already commented above - the possibility to
restore a device and its descendants from a different devicegraph (a backup
performed when entering the "Add RAID" workflow, in this case). So the whole
partition and related devices can be restored if the partition is taken out of
the list of selected ones.
