# Storage proposal: current (yast-storage-ng) and old (yast-storage) approach

This document describes the storage proposals of both yast-storage and
yast-storage-ng (mainly focusing on the latter), with a brief
explanation of how they work and how both can/must be influenced by the settings
coming from `control.xml` and other sources.

## Current proposal (yast-storage-ng) - overview

The settings used to influence the behavior of the storage proposal are read from
the `partitioning` section of `control.xml`. Based on those settings, the
algorithm described below will setup the partitions and LVM volumes in the
system disks.

### Storage proposal settings

This chapter presents a brief summary of the elements in the mentioned `partitioning`
section. More detailed information can be found at:
  * the [control.rnc](https://github.com/yast/yast-installation-control/blob/master/control/control.rnc)
    specification,
  * the [corresponding section](https://github.com/yast/yast-installation/blob/master/doc/control-file.md#partitioning)
    of the official control.xml documentation

Most settings are grouped into two subsections of that `partitioning` section:
  * `proposal`
    Holds general settings for the proposal.
  * `volumes`
    A list of `volume` elements holding specific settings for each volume that should be created,
    including the root (`/`) file-system and any other separate mount point, like `swap` or
    `/home`.

### How the proposal distributes the space

The current proposal uses the following two-steps approach when deciding which
partitions should be created/deleted/resized and how much space to assign to
every new partition or logical volume.

#### First step

A first step decides which volumes will be needed. Each volume will originate a
partition or a LV in the second step.

The basic list of planned volumes will be taken from the `volumes` subsection in
`control.xml`, except for those the user explicitly disables. In addition to
those initial volumes, the proposal can plan more for extra partitions needed to
boot the system.

For each volume, three sizes are specified - minimum, desired, and maximum. The
maximum size can have the special value `unlimited`. In addition, every volume
gets a weight.

#### Second Step

The second step creates the necessary partitions and logical volumes to make
those planned volumes fit in the disk. It makes a first attempt targeting the
"desired" size. If that fails, it tries again but aiming just for the "minimum"
size. During each attempt, preexisting partitions are resized or deleted
according to four settings that can be influenced by the user. See below.

If more space than the target is freed (or is available from the beginning),
that extra space is distributed among all the volumes. The ratio of space is
decided using the corresponding weights. No volume will grow beyond its maximum
size, even if that means leaving unused space on the disk.

Using LVM doesn't make a big difference. The VG (with its required PVs) is
created to accommodate the size of all the created LVs, although the exact
behavior in that regard can be influenced. See below.

#### Making space

Every one of the explained attempts to allocate the partitions or LVM logical
volumes may need to previously free the space used in the disks. Obviously,
that's achieved deleting or resizing existing partitions. The selection of
partitions to resize or delete can be influenced with four settings that are
configurable by the user in every proposal run.

  * `windows_delete_mode`
    What to do regarding removal of existing partitions hosting a Windows system.
    * `none`: Never delete a Windows partition.
    * `ondemand`: Only delete the Windows partitions that must be removed in order to make
      the proposal possible.
    * `all`: Delete all Windows partitions, even if not needed.
  * `linux_delete_mode`
    The same but for partitions that are part of a Linux installation (partition
    id linux, swap, lvm or raid).
  * `other_delete_mode`
    For all other partitions that don't fit into the former two groups.
  * `resize_windows`
    Whether to resize Windows systems if needed.

#### Creation of LVM structures

As said before, using LVM doesn't make a big difference on how the proposal
works. It simply allocates LVM logical volumes instead of partitions. To
allocate such LVs, the proposal first needs to create (or reuse) a volume
group that is big enough, which usually means creating one or several physical
volumes.

If `lvm_vg_strategy` is set to "use_needed", the VG is created to perfectly fit
the sizes of all the created LVs, with no extra unused space. If that setting is
set to "use_available", the VG created by the proposal will use all the space
that has become available after deleting partitions according to the settings
explained above. A third value of the setting was planned in order to use a
fixed size for the VG (which should be, of course, equal or bigger than the sum
of the max sizes of all the volumes), but that has not been implemented so far
because the original use-case seems to not be relevant nowadays.

## Current proposal (yast-storage-ng) - by example

The configuration of the storage proposal for a given product or system role is
much more powerful and flexible than it used to be with the old (yast-storage)
system, but it's also more complex. Since explaining complex stuff is usually
best addressed via examples, this section shows how the behavior of the old
proposal can be reproduced in the current one by setting the right configuration
in `control.xml` for several example products.  It also illustrates how
easy it is to accommodate changes and new use cases that were impossible to
achieve with the old system.

For details that are not self-explanatory in the examples (or that are omitted
for simplicity), remember to check the
[partitioning section](https://github.com/yast/yast-installation/blob/master/doc/control-file.md#partitioning)
of the main control.xml documentation.

### Example: SLES

This `partitioning` section would emulate quite closely the behavior of SLES-12,
proposing always `/` and swap partitions (or logical volumes, if the user
decides to use LVM). In addition, it will give the user the opportunity to have
a separate `/home` partition/volume. That option will be enabled by default if
there is enough space to create a home of at least 5 GiB.

Some values are a direct translation of the legacy `control.xml` and others
(like the relationship with Windows partitions) are inferred from the typical SLES
use case.

```xml
<partitioning>
  <proposal>
    <lvm config:type="boolean">false</lvm>
    <windows_delete_mode config:type="symbol">all</windows_delete_mode>
    <linux_delete_mode config:type="symbol">ondemand</linux_delete_mode>
    <other_delete_mode config:type="symbol">ondemand</other_delete_mode>
    <lvm_vg_strategy config:type="symbol">use_available</lvm_vg_strategy>
  </proposal>

  <volumes config:type="list">
    <!-- The root filesystem -->
    <volume>
      <mount_point>/</mount_point>
      <fs_type>btrfs</fs_type>
      <desired_size config:type="disksize">5 GiB</desired_size>
      <min_size config:type="disksize">3 GiB</min_size>
      <max_size config:type="disksize">10 GiB</max_size>
      <weight config:type="integer">35</weight>

      <snapshots config:type="boolean">true</snapshots>
      <snapshots_configurable config:type="boolean">true</snapshots_configurable>
      <snapshots_percentage config:type="integer">300</snapshots_percentage>
      <!-- Disable snapshots for / if disabling /home and giving up on
           enlarged swap is not enough -->
      <disable_order config:type="integer">3</disable_order>

      <btrfs_default_subvolume>@</btrfs_default_subvolume>
      <subvolumes config:type="list">
        <!--
          This would be the same than the <subvolumes> list in the current
          (old) control.xml. Reproducing the whole list doesn't make much sense.
        -->
      </subvolumes>
    </volume>

    <!-- The home filesystem -->
    <volume>
      <mount_point>/home</mount_point>
      <fs_type>xfs</fs_type>

      <proposed config:type="boolean">true</proposed>
      <proposed_configurable config:type="boolean">true</proposed_configurable>
      <!-- Disable it in first place if we don't fit in the disk -->
      <disable_order config:type="integer">1</disable_order>

      <desired_size config:type="disksize">5 GiB</desired_size>
      <min_size config:type="disksize">5 GiB</min_size>
      <!-- Omitting max_size is also possible, but since we have an explicit
           max_size_lvm and fallback_for_max_size it's more clear to
           include it. -->
      <max_size config:type="disksize">unlimited</max_size>
      <max_size_lvm config:type="disksize">25 GiB</max_size_lvm>
      <weight config:type="integer">55</weight>
      <!-- If this volume is disabled and LVM is not being used, we want
           "/" to become greedy (unlimited max) -->
      <fallback_for_max_size>/</fallback_for_max_size>
    </volume>

    <!-- The swap volume -->
    <volume>
      <mount_point>swap</mount_point>
      <fs_type>swap</fs_type>

      <desired_size config:type="disksize">2 GiB</desired_size>
      <min_size config:type="disksize">1 GiB</min_size>
      <max_size config:type="disksize">2 GiB</max_size>
      <weight config:type="integer">10</weight>
      <adjust_by_ram config:type="boolean">true</adjust_by_ram>
      <adjust_by_ram_configurable config:type="boolean">true</adjust_by_ram_configurable>
      <!-- Give up on enlarging to RAM if we still don't fit in the disk
           after disabling separate home -->
      <disable_order config:type="integer">2</disable_order>
    </volume>
  </volumes>
</partitioning>
```

### Example: openSUSE

In the case of emulating the openSUSE Leap 42 proposal, the `volumes` subsection
wouldn't be much different from SLES-12, with the exception of some sizes. But the
`proposal` one would probably look like this (more MS Windows friendly).

```xml
<proposal>
  <lvm config:type="boolean">false</lvm>
  <resize_windows config:type="boolean">true</resize_windows>
  <windows_delete_mode config:type="symbol">ondemand</windows_delete_mode>
  <linux_delete_mode config:type="symbol">ondemand</linux_delete_mode>
  <other_delete_mode config:type="symbol">ondemand</other_delete_mode>
  <lvm_vg_strategy config:type="symbol">use_available</lvm_vg_strategy>
</proposal>
```

### Example: SLES4SAP

Just a tentative to show some possibilities, although maybe some aspects
don't fit the current SAP requirements exactly.

Although the users would still be able to change the proposal settings, they
wouldn't be able to change the filesystem type for `/` (Btrfs) or to disable the
usage of snapshots on it. There is also no way (other than using the expert
partitioner) to request a separate `/home` volume. The proposed swap would be
much bigger than the typical SLES one.

Although is not part of this example, it would be easy to configure the proposal
to suggest any other arbitrary set of separate data volumes instead of home
(similar to `/var/lib/docker` in the CaaSP example below) that the user could
enable or disable in the "Guided Setup" (the former "Proposal Settings").

```xml
<partitioning>
  <proposal>
    <lvm config:type="boolean">true</lvm>
    <windows_delete_mode config:type="symbol">all</windows_delete_mode>
    <linux_delete_mode config:type="symbol">ondemand</linux_delete_mode>
    <other_delete_mode config:type="symbol">ondemand</other_delete_mode>
    <lvm_vg_strategy config:type="symbol">use_available</lvm_vg_strategy>
  </proposal>

  <volumes config:type="list">
    <!-- The '/' filesystem -->
    <volume>
      <mount_point>/</mount_point>
      <!-- Enforce Btrfs for root by not offering any other option -->
      <fs_type>btrfs</fs_type>
      <fs_types>btrfs</fs_types>
      <desired_size config:type="disksize">40 GiB</desired_size>
      <min_size config:type="disksize">30 GiB</min_size>
      <max_size config:type="disksize">60 GiB</max_size>
      <weight config:type="integer">50</weight>
      <!-- Always use snapshots, no matter what -->
      <snapshots config:type="boolean">true</snapshots>
      <snapshots_configurable config:type="boolean">false</snapshots_configurable>

      <!-- You don't want to miss the / volume -->
      <proposed_configurable config:type="boolean">false</proposed_configurable>

      <btrfs_default_subvolume>@</btrfs_default_subvolume>
      <subvolumes config:type="list">
        <!--
          This would be the same than the <subvolumes> list in the current
          (old) control.xml. Reproducing the whole list doesn't make much sense.
        -->
      </subvolumes>
    </volume>

    <!-- The swap volume -->
    <volume>
      <mount_point>swap</mount_point>
      <fs_type>swap</fs_type>

      <desired_size config:type="disksize">6 GiB</desired_size>
      <min_size config:type="disksize">4 GiB</min_size>
      <max_size config:type="disksize">10 GiB</max_size>
      <weight config:type="integer">50</weight>
    </volume>

    <!--
      No home filesystem, so the option of a separate home is not even
      offered to the user.
      On the other hand, a separate data volume (optional or mandatory) could
      be defined.
    -->

  </volumes>
</partitioning>
```

### Example: CaaSP

Once again, this example is just an approximation to show the possibilities.
CaaSP doesn't allow the user to run the Guided Setup, so the result of the
proposal cannot be influenced. This `partitioning` section would enforce the
proposal to:

  * use the whole disk (deleting previous partitions),
  * use partitions (no LVM),
  * always use Btrfs with snapshots for `/` (failing to make a proposal
    if that's not possible instead of giving up on snapshots like the current
    proposal does),
  * never propose separate `/home` or swap partitions,
  * propose a separate `/var/lib/docker` partition if there is enough space for
    it (basically if the disk is bigger than 20 GiB, according to the sizes in
    the example).

```xml
<partitioning>
  <!-- Advise the user against using the expert partitioner -->
  <expert_partitioner_warning config:type="boolean">true</expert_partitioner_warning>

  <!-- All default settings will become final, since the user can't change them -->
  <proposal>
    <lvm config:type="boolean">false</lvm>
    <!-- Delete all previous partitions -->
    <windows_delete_mode config:type="symbol">all</windows_delete_mode>
    <linux_delete_mode config:type="symbol">all</linux_delete_mode>
    <other_delete_mode config:type="symbol">all</other_delete_mode>
  </proposal>

  <volumes config:type="list">
    <!-- The '/' filesystem -->
    <volume>
      <mount_point>/</mount_point>
      <fs_type>btrfs</fs_type>
      <desired_size config:type="disksize">15 GiB</desired_size>
      <min_size config:type="disksize">10 GiB</min_size>
      <max_size config:type="disksize">30 GiB</max_size>
      <weight config:type="integer">80</weight>
      <!-- Always use snapshots, no matter what -->
      <snapshots config:type="boolean">true</snapshots>
      <snapshots_configurable config:type="boolean">false</snapshots_configurable>

      <!-- You don't want to miss the / volume -->
      <proposed_configurable config:type="boolean">false</proposed_configurable>

      <btrfs_default_subvolume>@</btrfs_default_subvolume>

      <!-- Make '/' volume read-only -->
      <btrfs_read_only config:type="boolean">true</btrfs_read_only>

      <subvolumes config:type="list">
        <!--
          This would be the same than the <subvolumes> list in the current
          (old) control.xml. Reproducing the whole list doesn't make much sense.
        -->
      </subvolumes>
    </volume>

    <!-- Use /var/lib/docker as separate partition if 10+ GiB available -->
    <volume>
      <mount_point>/var/lib/docker</mount_point>
      <fs_type>btrfs</fs_type>
      <snapshots config:type="boolean">false</snapshots>
      <snapshots_configurable config:type="boolean">false</snapshots_configurable>

      <desired_size config:type="disksize">15 GiB</desired_size>
      <min_size config:type="disksize">10 GiB</min_size>
      <max_size config:type="disksize">unlimited</max_size>
      <weight config:type="integer">20</weight>

      <!-- Give up separate partition if it doesn't fit -->
      <disable_order config:type="integer">1</disable_order>

      <!-- If this volume is disabled, we want "/" to increase -->
      <!-- (don't increase min size as it would be pointless) -->
      <fallback_for_desired_size>/</fallback_for_desired_size>
      <fallback_for_max_size>/</fallback_for_max_size>
      <fallback_for_weight>/</fallback_for_weight>
    </volume>

    <!-- No swap partition is defined, so it's never created -->
  </volumes>
</partitioning>
```

## The old proposal (yast-storage)

Most settings used to influence the behavior of the old yast-storage were read
from the `partitioning` section of `control.xml`, with some settings having a
fallback in `/etc/sysconfig`.

This chapter presents a brief summary of the structure of that old
`partitioning` section.

### Storage proposal settings

The explanation on how every option relates to the others (which is far from
being straightforward) can be found below, in the section titled "How the old
proposal distributed the space".

#### Proposal-specific options

  * `try_separate_home`
  * `limit_try_home`
  * `home_path`
  * `home_fs`
  * `root_fs`
  * `root_space_percent`
  * `root_base_size`
  * `root_max_size`
  * `proposal_lvm`
  * `vm_desired_size`
  * `vm_home_max_size`
  * `vm_keep_unpartitioned_region`
  * `btrfs_increase_percentage`

#### Proposal and partitioner options

In addition to the list above, there were two options, related to the usage of
Btrfs for the root filesystem, that were used by the proposal and also by the
expert partitioner when suggesting the default configuration for such
filesystem.

  * `subvolumes`
    Optional list of Btrfs subvolumes. If it is missing, a
    hard-coded list is used.
  * `btrfs_default_subvolume`
    The default subvolume is not represented by an
    entry in the `subvolumes` list, but with a separate option that specifies only
    its path.

#### Other general options

The `partitioning` section of `control.xml` for yast-storage went beyond the
configuration of the proposal's behavior. It also contained some options to
influence other aspect of YaST, mainly the installer.

  * `expert_partitioner_warning`
    Whether an extra warning pop-up should be
    displayed if the user enters the expert partitioner during installation.
  * `use_separate_multipath_module`
    Whether to call the `multipath` client
    from the yast2-multipath package. If false, the `multipath-simple` client
    from yast2-storage is used.

#### Obsolete options

The following options were used by the so-called "flexible partitioning"
feature, that was dropped in SLE-12 already: 
  * `prefer_remove`
  * `remove_special_partitions`
  * `partitions`

### How the old proposal distributed the space

This part of the document explains how the storage proposal works in
yast-storage. The content of this section is inferred from the existing
documentation, some inspection of `StorageProposal.rb` and quite some manual
tests. It may not be 100% accurate, specially since many changes have been
introduced over time.

The explanations are intentionally simplified to keep the focus on the main
topic: the influence of the settings in the behavior of the proposal
in the most common and simple scenarios.

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

#### Partition-based distribution

The old proposal tries to use all the available free space. There are
settings to influence the minimum size of the partitions but not to limit the
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

#### LVM-based distribution

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
`root_space_percent` is also used to decide the ratio but root is never
proposed to be bigger than `root_max_size`, no matter if there is a separate
home or not. If a separate home is desired, it is never proposed to be bigger
than `vm_home_max_size`.

As a result, it's very likely that the resulting VG will contain a lot of
unassigned space, especially if `vm_keep_unpartitioned_region` is false (which is
the default).

## References

Some fate entries that influenced the old proposal behavior

* [Fate#303594](https://fate.suse.com/303594) - Probable origin of `vm_desired_size`
* [Fate#308490](https://fate.suse.com/308490) - Reason to add `vm_keep_unpartitioned_region`
