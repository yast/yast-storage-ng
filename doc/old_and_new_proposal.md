# Changes in the storage proposal approach

This document covers the differences between the storage proposals of
yast-storage and yast-storage-ng, with a brief explanation of how they work and
how both can/must be influenced by the settings coming from `control.xml` and
other sources.

The explanations are intentionally simplified to keep the focus on the main
topic: the influence of the settings in the behavior of both proposals in the
most common and simple scenarios.

## Proposal settings used by the old proposal

Most settings used to influence the old proposal are read from `control.xml` and
are listed and documented at
[yast-storage/doc/](https://github.com/yast/yast-storage/blob/master/doc/config.xml.description).

In addition to those, the default filesystem types to use when formating "/" and
"/home" are read from `/etc/sysconfig`.

## How the old proposal distributes the space

The content of this section is inferred from the existing documentation, some
inspection of `StorageProposal.rb` and quite some manual tests. It may not be
100% accurate, specially since many changes have been introduced over time.

For clarity reasons, the logic used to assign space to swap or the special
partitions needed for booting is not covered in this section. Those values are
decided and fixed at the beginning of the process, so they have relatively
small influence on how the space is reclaimed or distributed.

There are two parameters to decide if a separate home partition or logical
volume should be proposed: `try_separate_home` (boolean) and
`limit_try_home` (size). A separate home will be proposed if `try_separate_home`
is true and the available space is greater than or equal to `limit_try_home`.

That being said, the space is distributed in a different way with and without
LVM.

### Partition-based distribution

The old proposal tries to use all the available free space. There are
settings to influence the minimum size of the partitions, but not to limit the
maximum free space reclaimed for the system.

Interestingly enough, if there is not enough free space, the old proposal tries
to reformat the found Linux partitions instead of deleting them and creating new
partitions with the desired sizes.

As mentioned, the proposal tries to use all the existing free space. If a
separate home is proposed, the space is distributed among home and root, based on
the ratio expressed by `root_space_percent`. There is a limitation to that
distribution - if root reaches `root_max_size`, it will not grow further and the
rest of the space is assigned to home.

If there is no separate home, `root_max_size` has no effect and root grows until
filling all the available space.

### LVM-based distribution

Again for clarity reasons, reusing preexisting VGs is left out of this section,
that will focus on the situation in which the proposal needs to create a VG.

The base and maximum sizes for root or home are not taken in consideration when
deciding the size of the created VG. There are independent settings for that.

If `vm_keep_unpartitioned_region` is false, the created VG will be as big as
possible. That means the proposal will create PVs completely filling the
available spaces. In addition all preexisting Linux partitions will be turned
into PVs and added to the VG.

If `vm_keep_unpartitioned_region` is true, a PV of `vm_desired_size` will be
created (this is the only case in which the proposal can be forced to leave
some unused free space). Again, all preexisting Linux partitions will be turned
into PVs and also added to the VG.

After creating the VG, its space is distributed among home and root following
slightly different rules than in the partition-based approach.
`root_space_percent` is also used to decide the ratio, but root is never
proposed to be bigger than `root_max_size`, no matter if there is a separate
home or not. If a separate home is desired, its never proposed to be bigger
than `vm_home_max_size`.

As a result, it's very likely that the resulting VG will contain a lot of
unassigned space, specially if `vm_keep_unpartitioned_region` is false (which is
the default).

## How the new proposal distributes the space (so far)

The new proposal uses the following two-steps approach when 
deciding which partitions should be created/deleted/resized and how much
space to assign to every new partition or logical volume.

A first step decides which volumes will be needed. Each volume will originate a
partition or a LV in the second step. There are always at least two planned volumes, one
for swap and one for root. In addition, and depending on the settings, there
will be another planned volume for home and several ones for additional partitions
needed to boot the system.

The set of volumes generated during this first step is obviously influenced by
the already mentioned proposal settings.

For each volume, three sizes are specified - the minimum one, the desired one
and the maximum. The maximum size can have the special value "unlimited". In
addition, every volume gets a "weight" (so far, based on the
`root_space_percent` setting).

The second step creates the necessary partitions and logical volumes to make
those planned volumes fit in the disk. It makes a first attempt targeting the
"desired" size. If that fails, it tries again but aiming just for the "minimum"
size. Preexisting partitions are resized or deleted until freeing the target
size (there is no need to delete more partitions that strictly needed).

If more space than the target is freed (or is available from the beginning),
that extra space is distributed among all the volumes. The ratio of space is
decided using the corresponding weights. No volume will grow beyond its maximum
size, even if that means leaving unused space in the disk.

Using LVM doesn't make a big difference. The VG is created to perfectly fit the
sizes of all the created LVs, with no extra unused space.

## Relationship between the new proposal and the old settings

The following settings are currently read by the new proposal and used with
exactly the same meaning.

 * `try_separate_home`
 * `root_space_percent`
 * `proposal_lvm`
 * `btrfs_increase_percentage`

The following settings are read and used in a slightly different way.

 * `root_base_size` is used to set the min size for the root planned volume.
 * `root_max_size` is used to set the max size for the root planned volume. That
   is different from the old proposal because that maximum size is always
   honored in the new proposal, while in the old one the setting only applies to
   some scenarios (LVM and partition-based with a separate home).
 * `vm_home_max_size` is used to set the max size for the home planned volume.
   Again, that means the setting is always honored, in contrast to the old
   proposal that only uses it if LVM is proposed.

The following settings are read, but not used so far.

 * `limit_try_home` because the new proposal does not implement the
   corresponding check so far.
 * `swap_for_suspend` is not used because the logic to calculate the swap size
   is still not definitive. Moreover, the usefulness of the setting is under
   discussion (Ken suggested a dropping attempt).
 * `btrfs_default_subvolume` is not used because subvolumes are still not
   proposed (work in progress).
 * `root_subvolume_read_only` same than above.

The following settings are not read because, as can be inferred from the
sections above, they don't fit the current status of the new algorithm.

 * `vm_keep_unpartitioned_region`
 * `vm_desired_size`

## Closing the gap

As explained before, the old and new proposals follow different philosophies.
The new one consistently follows the approach of trying to accommodate a
group of planned volumes with minimum, desired and maximum sizes. On the other
hand, the behavior of the old proposal may look sometimes like a set of several
algorithms designed ad-hoc for different scenarios. As a result, the exact
meaning of most settings is different based on the value of the other ones.

Fortunately, the new proposal is flexible enough to somehow _emulate_ the
behavior of the old one to a big extend. This section proposes a way to define
the planned volumes in a way that tries to honor the legacy behavior and
settings.

This is not the only possible way to achieve that. There are more options
including, of course, the option of not trying to emulate the old behavior
and/or use the old settings at all.

### Emulating the partition-based old proposal

* Root volume
 * Max size: `root_max_size` if a separate home is proposed, unlimited otherwise.
 * Desired size: (`root_base_size` + `root_max_size`) / 2
 * Min size: `root_base_size`

* Home volume
 * Max size: unlimited
 * Desired and min sizes: same values than for the root volume.

### Emulating the LVM-based old proposal

The behavior of the old proposal is completely different depending on the value
of `vm_keep_unpartitioned_region`. If that setting evaluates to true, an
acceptable way to emulate the behaviour with no modifications in the current
code would be:

* Root volume
  * Max size: `root_max_size`
  * Desired size: (`root_base_size` + `root_max_size`) / 2
  * Min size: `root_base_size`

* Home volume
  * Max size: the smallest of these two values
    * `vm_home_max_size`
    * `vm_desired_size` - `root_max_size`
  * Desired and min sizes: the smallest of these two values
    * The corresponding value for the root size
    * `vm_desired_size` - X, where X is the corresponding value for the root size

On the other hand, to fully emulate the behavior of the old proposal with
`vm_keep_unpartitioned_region` set to false two things would be needed. First,
to set the planned volume sizes like this:

* Root volume
 * Max size: `root_max_size`
 * Desired size: (`root_base_size` + `root_max_size`) / 2
 * Min size: `root_base_size`

* Home volume
 * Max size: `vm_home_max_size`
 * Desired and min sizes: same values than for the root volume.

In addition to that, the component generating the LVM physical volumes would
need a new argument to indicate that we want the new PVs to be as big as
possible. Right now it just proposes PVs that are big enough to fulfill the
space requisites of the planned volumes, but implementing an optional _greedy_
mode would imply changing just a couple of lines of code in the new proposal.

## References

Some fate entries that influenced the old proposal behavior

* [Fate#303594](https://fate.suse.com/303594) - Probable origin of `vm_desired_size`
* [Fate#308490](https://fate.suse.com/308490) - Reason to add `vm_keep_unpartitioned_region`
