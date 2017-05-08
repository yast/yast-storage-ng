# Implementing AutoYaST partitioning in Storage-NG


## About this document

This is a follow-up on [this
document](https://mailman.suse.de/mlarch/SuSE/yast-internal/2017/yast-internal.2017.04/msg00124.html)
sent to the yast-internal mailing list (only accessible within the SUSE
company network). That document categorizes the AutoYaST partitioning use cases
in three levels and states the first two are already close to be covered by just
reusing the existing installation proposal, almost as-is.

This document describes how some components of that installation proposal could
also be reused to implement many of the features of the third level.


## TL;DR

After finishing an ongoing refactoring of the proposal code, the following
classes could be reused (with small modifications/enhancements) to implement
the so-called level 3 of AutoYaST: `PlannedPartition`, `PlannedLv`, `PlannedVg`,
`PartitionKiller`, `PartitionCreator`, `LvmCreator` and
`SpaceDistributionCalculator`.

In addition, two similar but new classes should need to be implemented:
`PlannedMd` and `MdCreator`.

Reusing an existing mount table (fstab) is a different beast. Hard to fit into
the current model and maybe worth dropping.


## What we already have

The current installation proposal consist basically of two phases:

* First a list of `PlannedVolume` objects is generated, describing all the
  partitions or LVs that are needed to install the system based on the
  ProposalSettings.
* Afterwards, a new devicegraph is generated based on the initial one and on
  the list of planned volumes. During that process, preexisting partitions and
  logical volumes are deleted and resize on demand and the optimal distribution
  of partitions is calculated.

Each `PlannedVolume` contains both a desired size and a minimal size. So, in the
worst case the whole process is repeated twice (first using the desired sizes
and then falling-back to the min).

There is a [pending pull request](https://github.com/yast/yast-storage-ng/pull/179)
(Iván's Hackweek) with a refactoring of the current proposal in which, at the
beginning of every one of the two attempts, the list of planned volumes is
separated into two more specific and explicit lists of `PlannedPartition` and
`PlannedLv` objects. Those objects contain only one target size (so no desired vs
min). The original goal of the PR was to improve readability of many components
but, in addition to that, we found it would also help to implement AutoYaST
specific logic in the proper way.

The rest of this document assumes the mentioned pull request is finished and
merged and, thus, the `PlannedPartition` and `PlannedLv` classes are there, in
addition to the existing and more generic `PlannedVolume` (and
`PlannedSubvolume`). Of course, the name of some classes referenced on this
document can change (for the best) as part of the mentioned pull request.

For more information about the internal structure of the installation proposal,
check [proposal.md](./proposal.md).


## Level 3 of AutoYaST and the installation proposal

[This gist](https://gist.github.com/imobachgs/0f4049c2955b858c0713896210306aa1)
presents many use cases of the so-called level 3 of AutoYaST partitioning, based
on examples found in the AutoYaST documentation.

The process followed by AutoYaST is quite different from the proposal one, but
the concept of `PlannedPartition`, `PlannedLv` and several auxiliary classes
that take list of those as input to perform operations can be reused to a big
extend.


## Adapting the existing code

### Features that can be added to the existing components/classes

The following features could, at first sight, be added to the current system
with a relatively low impact in the current structure and philosophy of the
code.

* We need to add the `mountby`, `fstopt` and `mkfs_options` attributes to the
  `PlannedPartition` and `PlannedLv` classes. The effort to implement them looks
  quite reasonable at first sight, although it has been suggested to drop
  `fstopt` and `mkfs_options` (which is, of course, even less effort than
  implementing them).

* The `partition_nr` tag in the AutoYaST profile is useful for two goals. The
  first one if defining a partition to reuse, something already covered by the
  existing proposal code. The second goal would be to enforce the usage of a
  particular number for newly created partitions, something that would require
  some modifications in the current code.

* The effort to implement the `disklabel` property, that allows to specify the
  type of partition table to use in each drive, also looks acceptable. Once
  again, dropping support for it (which means YaST will always decide which
  partition table type to use, as the current proposal does) can also be a
  reasonable option.

### Handling LVM

The approach to LVM of the level 3 of AutoYaST and the current proposal is
totally different.

In a normal installation, there is only one VG (that can be a reused one) and
the number and sizes of the PVs are calculated dynamically based on the needs
defined by the `PlannedLv` objects and the restrictions imposed by the
`PlannedPartition` ones. In other words, not all the planned partitions are
known at the beginning of the process, those partitions that will become PVs are
planned while generating the resulting devicegraph. All the LVM-related logic is
encapsulated in a class called `LvmHelper`.

With AutoYaST the process is more straightforward. The exact list of PVs is
specified in the AutoYaST profile. On the other hand, there can be several VGs
involved.

It makes sense to break the current `LvmHelper` into two components. The first
one will generate `PlannedPartition` objects as described (to become PVs) and
also an object of a new `PlannedVg` class. The second component, that should
probably be called `LvmCreator` for consistency reasons, could take collections
of planned partitions (PVs), planned VGs and planned LVs as input and create
the corresponding structures in the target devicegraph. As a bonus, that would
be more consistent with the rest of the current proposal mechanisms.

The new `PlannedVg` and `LvmCreator` classes will be re-used by the AutoYaST
proposal and will have the capabilities needed to honor the following properties
from the AutoYaST profile: `pesize`, `lv_name`, `stripes`, `stripe-size`,
`lvm_group`, `pool`, `used_pool` and `keep_unknown_lv`.


## The AutoYaST level 3 procedure

### Phase one: assigning the drives

The `partitioning` section of the AutoYaST profile is organized into drives
containing a list of partitions each. The result must honor that organization.
I.e., two partitions that are listed in the same drive will always end up in the
same disk and two partitions in different drives cannot end up sharing the disk.

The matching between a drive and the real disk can be done explicitly in the
profile (using the `device` tag) or can be left for AutoYaST to decide. In the
latter case, the algorithm used by AutoYaST is deadly simple - it just tries to
use the first available device that is not explicitly skipped (there is also a
syntax for skipping devices). The documentation states it tries to find a
device that "looks reasonable", but in reality it just uses whatever is not
skipped, with no optimization in place or even without checking if the device is
big enough.

Thus, it would be easy to implement the same algorithm to decide beforehand the
disk allocating every planned partition.

The `device` tag can have an undocumented value `ask` that will show a pop-up
asking the user which disk to use for a given device specification. It could be
dropped, although implementing it (initially or at a later point in time)
should not be difficult.

### Phase two: deleting and resizing old stuff

All delete and resize operations are specified in the AutoYaST profile and,
thus, can be performed in a very early stage. No need to calculate resizing or
deleting on demand during the process like in the proposal procedure.

As soon as the matching between AutoYaST devices and real disks is known, the
corresponding destructive operations can be performed in the target devicegraph.

* Partition tables for devices with the `initialize` flag can be delete right
  away from the devicegraph.

* AutoYaST also makes possible to specify the concrete way in which a given
  partition must be resized (resizing LVs is explicitly unsupported). That can
  also be implemented as an initial operation in the devicegraph.

* The `use` tag in the profile can have the following values: `all`, `linux`,
  `free` or a number. The first two options are very similar to some options
  already implemented in the proposal, so they should be easy to implement.
  The fourth one is even more straightforward. The third options means doing
  nothing (even easier). All the removal operations can make use of the already
  existing class `Proposal::PartitionKiller`. As a last consideration,
  partitions marked to be reused in the AutoYaST profile must never be deleted.

### Phase three: planning new stuff

After freeing all the space, the profile information can already be used to
create objects of the existing `PlannedPartition`, `PlannedLv` and `PlannedVg`
classes. In addition, a new `PlannedMd` class should be developed to allow the
specification of a future RAID.

The size of every partition can be specified as a fixed size, as a percentage of
the total size to be used in the disk or with the keywords `max` and `auto`.
Since the disk for each partition and the space to be used in that disk will
be known beforehand, translating those sizes to attributes in the corresponding
`PlannedPartition` objects should be relatively easy.

Similar reasoning can be applied to the LV sizes.

During this phase, AutoYaST is also expected to propose any additional partition
required for booting, even if that partition is not present in the profile. The
class `BootRequirementsChecker` can be reused for that purpose.

### Phase four: making it real

The last phase consists in creating the new devices and it could, once again,
reuse many of the components of the current proposal.

* `SpaceDistributionCalculator` can be used to allocate the partitions in the
  disks and then `PartitionCreator` can be used to really create those
  partitions in the devicegraph.

* Then a new `MdCreator` class should take care of making the `PlannedMd` real
  in the devicegraph. These are the only classes in this regard that would need
  to be developed from scratch.

* Last but not least, `LvmCreator` could be used to create/reuse the planned
  VGs and LVs.


## Features that are hard to accommodate in the current model

* As already mentioned by the [original overview
document](https://mailman.suse.de/mlarch/SuSE/yast-internal/2017/yast-internal.2017.04/msg00124.html),
there is an alternative to the AutoYaST `partitioning` section that can be used
to [reuse an existing mount table
(fstab)](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#ay.partition_fstab).
That section describes a completely different behavior that is, in fact,
incompatible with the `partitioning` one. As stated in the original document, it
makes sense to try to drop that feature completely.

* When the size of the partitions in a drive are specified as fixed values (e.g.
"10Gb") but they don't fit in the disk, currently AutoYaST reduces the size of
the biggest partition as much as needed to make all the partitions fit. This
undocumented behavior can be a valid safety measure in several scenarios in
which the profile describes an non achievable situation, but there is probably
no need to keep it, since the combination of fixed sizes, percentages, `max` and
`auto` should be enough to specify a working schema.

* Another undocumented feature makes possible to specify with total accuracy
(starting and ending block) the region in which a partition must be allocated.
Once again, this looks like a clear candidate for dropping, since it does not
fit into the general idea of letting YaST find the best possible layout and the
current behavior is, in fact, not documented.
