# Storage proposal: old (legacy) and new (ng) approach

This document covers the differences between the storage proposals of
yast-storage and yast-storage-ng, with a brief explanation of how they work and
how both can/must be influenced by the settings coming from `control.xml` and
other sources.

It also includes an overview of the corresponding `partitioning` section in
`control.xml`.

## Legacy proposal (yast-storage)

Most settings used to influence the behavior of the old yast-storage are read
from the `partitioning` section of `control.xml`, with some settings having a
fallback in `/etc/sysconfig`.

This chapter presents a brief summary of the structure of that
`partitioning` section. More detailed information can be found at:
  * the [control.rnc](https://github.com/yast/yast-installation-control/blob/master/control/control.rnc)
    specification,
  * the [corresponding
    section](https://github.com/yast/yast-installation/blob/master/doc/control-file.md#partitioning)
    of the official control.xml documentation,
  * the [yast-storage/doc/config.xml.description](https://github.com/yast/yast-storage/blob/master/doc/config.xml.description)
    document which details the settings understood by the proposal.

### Storage proposal settings

The exact meaning of each of the following options can be found in the last of
the above-mentioned documents. The explanation on how every option relates to
the others (which is far from being straightforward) can be found below, in the
section titled "How the old proposal distributes the space".

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

In addition to the list above, there are two options, related to the usage of
Btrfs for the root filesystem, that are used by the proposal and also by the
expert partitioner when suggesting the default configuration for such
filesystem.

  * `subvolumes`
    Optional list of Btrfs subvolumes. If it is missing, a
    hard-coded list is used. If the section is there but empty, no subvolumes
    are created. Each subvolume section has a mandatory `path` and optional
    `copy_on_write` and `archs` elements.
  * `btrfs_default_subvolume`
    The default subvolume is not represented by an
    entry in the `subvolumes` list, but with a separate option that specifies only
    its path. The path of the default subvolume is prepended to the path of all
    the other subvolumes in the filesystem, no matter if they come from the
    previous list or are manually added by the user of the partitioner.

#### Other general options

The `partitioning` section of `control.xml` goes beyond the configuration of
the proposal's behavior. It also contains some options to influence other
aspect of YaST, mainly the installer.

  * `proposal_settings_editable`
    Whether the user can change the proposal settings in the UI.
  * `expert_partitioner_warning`
    Whether an extra warning pop-up should be
    displayed if the user enters the expert partitioner during installation.
  * `use_separate_multipath_module`
    Whether to call the `multipath` client
    from the yast2-multipath package. If false, the `multipath-simple` client
    from yast2-storage is used.

#### Obsolete options

The following options were used by the not longer supported "flexible
partitioning" feature:
  * `prefer_remove`
  * `remove_special_partitions`
  * `partitions`

### How the old proposal distributes the space

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

## NG proposal (yast-storage-ng) - overview

Settings used to influence the behavior of the new storage code are read
from the `partitioning` section of `control.xml`.

> Note: You can either use the old legacy entries described in the last chapter or the
new settings.
> But: **Mixing old and new elements is not allowed.**

To use the new settings put a `proposal` *and* a `volumes` subsection into
`partitioning` in `control.xml`.


This chapter presents a brief summary of the new elements in the
`partitioning` section. More detailed information can be found at:
  * the [control.rnc](https://github.com/yast/yast-installation-control/blob/master/control/control.rnc)
    specification,
  * the [corresponding
    section](https://github.com/yast/yast-installation/blob/master/doc/control-file.md#partitioning)
    of the official control.xml documentation,

### Storage proposal settings

Most settings are grouped into two subsections of the `partitioning` section:
  * `proposal`
    Holds general settings for the proposal.
  * `volumes`
    A list of `volume` elements holding specific settings for each volume that should be created. Note
    that you really must add one section for each volume. There are no defaults.

Besides these, there is another element:
  * `expert_partitioner_warning` *(boolean, default: `false`)*

#### Global settings in `proposal` section

  * `lvm` *(boolean, default: `false`)*
  * `resize_windows` *(boolean, default: `true`)*
  * `windows_delete_mode` *(`none`, `ondemand`, `all`, default: `ondemand`)*
  * `linux_delete_mode` *(`none`, `ondemand`, `all`, default: `ondemand`)*
  * `other_delete_mode` *(`none`, `ondemand`, `all`, default: `ondemand`)*
  * (**FIXME - `use_vg_size` is not done yet**) `lvm_vg_strategy` *(`use_available`, `use_needed`, `use_vg_size`, default: `use_available`)*
  * (**FIXME - not done**)`lvm_vg_size` *(disksize, default: `0 B`)*
  * `proposal_settings_editable` *(boolean, default: `true`)*

#### Volume-specific settings in `volume` sections

  * `mount_point` *(string, default: no mountpoint)*
  * `proposed` *(boolean, default: `true`)*
  * `proposed_configurable` *(boolean, default: `false`)*
  * `fs_types` *(string, default: internal fallback list for '/' and '/home' volumes, empty list otherwise. In addition, the value of 'fs_type' is always included in the list )*
  * `fs_type` *(string, default: no type)*
  * `desired_size` *(disksize, default: `0 B`)*
  * `min_size` *(disksize, default: `0 B`)*
  * `max_size` *(disksize, default: `unlimited`)*
  * `max_size_lvm` *(disksize, default: `0 B`)*
  * `weight` *(integer, default: `0`, so extra size is not assigned)*
  * `adjust_by_ram` *(boolean, default: `false`)*
  * `adjust_by_ram_configurable` *(boolean, default: `false`)*
  * `fallback_for_min_size` *(string, default: no fallback)*
  * `fallback_for_max_size` *(string, default: no fallback)*
  * `fallback_for_max_size_lvm` *(string, default: no fallback)*
  * `fallback_for_weight` *(string, default: no fallback)*
  * `snapshots` *(boolean, default: `false`)*
  * `snapshots_configurable` *(boolean, default: `false`)*
  * `snapshots_size` *(disksize, default: `0 B`)*
  * `snapshots_percentage` *(integer, default: `0`)*
  * `subvolumes` *(subsection, default: either empty list or internal fallback list for '/' volume)*
  * `btrfs_default_subvolume` *(string, default: no special default subvolume)*
  * `disable_order` *(integer, default: never disabled)*

The `subvolumes` section holds a list of elements describing Btrfs
subsections. The section uses the same format as in the legacy code.

> Note: If `btrfs_default_subvolume` is set it is implicitly added to the `subvolumes` list.

### How the new proposal distributes the space

The new proposal uses the following two-steps approach when
deciding which partitions should be created/deleted/resized and how much
space to assign to every new partition or logical volume.

#### First step

A first step decides which volumes will be needed. Each volume will originate a
partition or a LV in the second step.

If the new format is used in the `partitioning` section in `control.xml`
the basic list of planned volumes will be
taken from the `volumes` subsection, except for those
the user explicitly disables. If the legacy format is used, there are always at
least two planned volumes (one for swap and one for root) and potentially
another one for home, based on the user's proposal settings.

In addition to those initial volumes, the proposal can plan more for extra
partitions needed to boot the system.

For each volume, three sizes are specified - minimum, desired, and
maximum. The maximum size can have the special value `unlimited`. In
addition, every volume gets a "weight" (so far, based on the
`root_space_percent` setting).

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
    The same but for partitions that are part of a
    Linux installation (partition id linux, swap, lvm or raid).
  * `other_delete_mode`
    For all other partitions that don't fit into the former two groups.
  * `resize_windows`
    Whether to resize Windows systems if needed.

#### Creation of LVM structures

> Note: this section describes some optional behavior that is still not
implemented in yast-storage-ng, although it would be very easy to add to the
current codebase.

As said before, using LVM doesn't make a big difference on how the proposal
works. It simply allocates LVM logical volumes instead of partitions. To
allocate such LVs, the proposal first needs to create (or reuse) a volume
group that is big enough, which usually means creating one or several physical
volumes.

In the current implementation, the VG is created to perfectly fit the sizes of
all the created LVs, with no extra unused space. It would be easy to add an
configuration option to force the proposal to take more space than strictly
needed by adding two possibilities: one for using all the available space
(after deleting partitions according to the settings explained above) and
another to use a fixed size for the VG (which must be, of course, equal or
bigger than the sum of the max sizes of all the volumes).

## NG proposal - by example

The redesign in the approach and code of the storage proposal explained above
also deserves a revamp of the corresponding section in the `control.xml` file.
This document presents a possible alternative for the `partitioning` section of
the control file. The goal is to provide more flexibility defining the products
behavior and better access to all the features of the new storage proposal.

But flexibility usually comes with the cost of complexity, and explaining
complex stuff is usually best addressed via examples. So this section shows how
it would be possible to reproduce the current behavior of several products via
the new proposal and the new format for `control.xml`. It also
illustrates how easy it would be to accommodate changes and new use cases that are
currently very hard or impossible to achieve.

The section after the examples dives into the new format in a more formal
and descriptive way, for all the details that are not included or
self-explanatory in the examples.

### Example: SLES

This `partitioning` section would emulate quite closely the current SLES
behavior, proposing always `/` and swap partitions (or logical volumes, if the
user decides to use LVM). In addition, it will give the user the opportunity to
have a separate `/home` partition/volume. That option will be enabled by default
if there is enough space to create a home of at least 5 GiB.

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

In the case of openSUSE, the `volumes` subsection wouldn't be much different
from SLES, with the exception of some sizes. But the `proposal` one would
probably look like this (more MS Windows friendly).

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

Just a tentative to show the possibilities of the new proposal and serve as an
inspiration. Maybe some aspects don't fit the SAP requirements exactly.

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
    <!-- Don't allow the user to use the Guided Setup -->
    <proposal_settings_editable config:type="boolean">false</proposal_settings_editable>
  </proposal>

  <volumes config:type="list">
    <!-- The '/' filesystem -->
    <volume>
      <mount_point>/</mount_point>
      <!-- Default == final, since the user can't change it (proposal_settings_editable == false) -->
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
      <!-- Default == final, since the user can't change it (proposal_settings_editable == false) -->
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

## NG proposal - the details

As explained in the previous examples section, a new format for the
`partitioning` section of `control.xml` is needed in order for the products to
take full advantage of the revamped proposal.

The proposed format is explained in reasonable depth in this section. The new
format aims to be very extensible for future requirements. As a result, it makes
very few assumptions which implies is more verbose than the old one.

In order to fully understand this section and its implications is important to
have read and understood the above section titled "How the new proposal
distributes the space".

### General structure

The new `partitioning` section contains
  * `expert_partitioner_warning`
    If `true`, an extra warning pop-up is
    displayed if the user enters the expert partitioner.

In addition to that, there are two new subsections: `proposal` and `volumes`.

### The `proposal` subsection

The `proposal` subsection is used to configure some general aspects of the
storage proposal (referenced as "guided setup" in the UI) and contains the
following options.

  * `lvm`
    Whether LVM should be used by default.
  * ~~`encrypt`
    Whether encryption should be used by default.~~
  * `windows_delete_mode`
    Default value for the automatic delete mode for
    Windows partitions. It can be `none`, `all` or `ondemand`. For more
    information, see the description of the new proposal above.
  * `linux_delete_mode`
    Default value for the automatic delete mode for
    Linux partitions. Again, it can be `none`, `all` or `ondemand`.
  * `other_delete_mode`
    Default value for the automatic delete mode for
    other partitions. Once again, it can be `none`, `all` or `ondemand`.
  * `resize_windows`
    Default value for the user setting deciding whether to
    resize Windows systems if needed.
  * `lvm_vg_strategy`
    If the user decides to use LVM, strategy to decide the
    size of the volume group (and, thus, the number and size of created physical
    volumes). There are three possible values.
    * `use_available`
      The VG will be created to use all the available space,
      thus the VG size could be greater than the sum of LVs sizes.
    * `use_needed`
      The created VG will match the requirements 1:1, so its size
      will be exactly the sum of all the LVs sizes.
    * `use_vg_size`
      The VG will have exactly the size specified in `lvm_vg_size`.
  * `lvm_vg_size`
    Specifies the predefined size of the LVM volume group if `lvm_vg_strategy` is `use_vg_size`.
  * `proposal_settings_editable`
    If `false`, the user is not allowed to change the proposal settings.

### The `volumes` subsection

The `volumes` subsection is responsible of specifying the
partitions (or logical volumes if LVM is chosen) to create during the proposal
and also the behavior of the expert partitioner regarding them.

It is a collection of `volume` subsections, each of them with the
options listed here. Having read the "How the new proposal distributes the
space" may be important to fully understand some of them.

  * `mount_point`
    Directory where the volume will be mounted in the system.
  * `proposed`
    Default value of the user setting deciding whether this volume
    should be created or skipped.
  * `proposed_configurable`
    Whether the user can change the previous setting
    in the UI. I.e. whether the user can activate/deactivate the volume. Of
    course, setting `proposed` to false and `proposed_configurable` also to
    false has the same effect than deleting the whole `<volume>` entry.
  * `fs_types`
    A collection of acceptable file system types. If no list is
    given, YaST will use a fallback based on the mount point.
  * `fs_type`
    Default file system type to format the volume.
  * `desired_size`
    Initial size to use in the first proposal attempt.
  * `min_size`
    Initial size to use in the second proposal attempt.
  * `max_size`
    Maximum size to assign to the volume. It can also contain the
    value `unlimited` (meaning as big as possible). This will be considered the
    default value if the option is not present.
  * `max_size_lvm`
    When LVM is used, this option can be used to override the
    value at `max_size`.
  * `weight`
    Value used to distribute the extra space (after assigning the
    initial ones) among the volumes.
  * `adjust_by_ram`
    Default value for the user setting deciding whether the
    initial and max sizes of each attempt should be adjusted based in the RAM
    size. So far the adaptation consists in ensuring all the sizes are, at
    least, as big as the RAM. In the future, an extra `adjust_by_ram_mode`
    option could be added to allow other approaches.
  * `adjust_by_ram_configurable`
    Whether the user can change the previous setting in the UI.
  * `fallback_for_min_size`
    Mount point of another volume. If the volume being
    defined is disabled, the `min_size` of that another volume will be increased
    by the `min_size` of this disabled volume.
  * `fallback_for_desired_size`
    Same than before, but for `desired_size`.
  * `fallback_for_max_size`
    Same than before, but for `max_size`.
  * `fallback_for_max_size_lvm`
    Same than before, but for `max_size_lvm`.
  * `fallback_for_weight`
    Same than before, but for the volume weight.

Some options only apply if the chosen filesystem type for the volume is
Btrfs, in some cases with the same name and meaning as in the old
`control.xml` format. The main difference is that now the setting will apply to
the volume in which it's included, not necessarily to the root ("/") one. In the
expert partitioner, if a Btrfs filesystem is created and assigned to the mount
point of the volume, these settings will also be used to suggest the filesystem
options.

  * `snapshots`
    Default value for the user setting deciding whether snapshots
    should be activated.
  * `snapshots_configurable`
    Whether the user can change the previous setting
    in the UI.
  * `snapshots_size`
    The initial
    and maximum sizes for the volume will be increased accordingly if snapshots
    are being used.
  * `snapshots_percentage`
    Like `snapshots_size` but as a percentage of the
    original sizes (just like the original `btrfs_increase_percentage`).
  * `subvolumes`
    Equivalent to the previous option that used to apply only to "/".
  * `btrfs_default_subvolume`
    Same than before.
  * `btrfs_read_only`
    Whether the root subvolume should be mounted read-only in /etc/fstab and
    its 'ro' Btrfs property should be set to _true_. This works only for Btrfs
    root filesystems. If another root filesystem type is chosen, this property
    is ignored. Its default value is _false_.

And finally there is an option that deserves a slightly more detailed
explanation.

  * `disable_order`
    Volumes with some value here will be disabled (or snapshots
    deactivated) if needed to make the initial proposal. See detailed
    explanation below.

Before any user interaction, an initial proposal with the default settings is
calculated. If YaST is not able to make space for all the volumes required by
those default settings, it will perform new attempts altering the settings. For
that, it will follow the `disable_order` for each volume with that field.

In the first iteration, it will look for the lowest number there. If
`adjust_by_ram_configurable` is true in that volume, it will disable `adjust_by_ram`. If
that is not enough and snapshots are optional but enabled, it will disable them
and try again (assuming Btrfs is being used). If that's still not enough, it
will disable the whole volume if it's optional.

If that's not enough, it will keep those settings and look for the next volume
with some value in `disable_order` to perform the same operation in a cumulative
fashion.

## Compatibility: using the new proposal with the old control.xml format

As explained before, the old and new proposals follow different philosophies.
The new one consistently follows the approach of trying to accommodate a
group of planned volumes with minimum, desired and maximum sizes. On the other
hand, the behavior of the old proposal may look sometimes like a set of several
algorithms designed ad-hoc for different scenarios. As a result, the exact
meaning of most settings is different based on the value of the other ones.

Fortunately, the new proposal is flexible enough to somehow _emulate_ the
behavior of the old one to a big extend. This section shows the current status
of that compatibility and suggests ways to define the planned volumes in a form
that tries to honor the legacy behavior and settings.

### Legacy options read by the new proposal code

The following settings are currently read by the new proposal and used with
exactly the same meaning.
  * `proposal_lvm`
  * `try_separate_home`
  * `limit_try_home`
  * `proposal_snapshots`
  * `root_space_percent`
  * `btrfs_increase_percentage`
  * `btrfs_default_subvolume`
  * `subvolumes`
  * `swap_for_suspend`

The following settings are read and used in a slightly different way.
 * `root_base_size`
   Used to set the min size for the root planned volume.
 * `root_max_size`
   Used to set the max size for the root planned volume. That
   is different from the old proposal because that maximum size is always
   honored in the new proposal, while in the old one the setting only applies to
   some scenarios (LVM and partition-based with a separate home).
 * `vm_home_max_size`
   Used to set the max size for the home planned volume.
   Again, that means the setting is always honored, in contrast to the old
   proposal that only uses it if LVM is proposed.

The following settings are not read because, as can be inferred from the
sections above, they don't fit the new algorithm. But they
could be honoured after implementing the alternative modes presented in the
section "Creation of LVM structures".
  * `vm_keep_unpartitioned_region`
  * `vm_desired_size`

### RFC: emulating the partition-based old proposal with the old settings

> NOTE: to be reviewed and refined

* Root volume
  * Max size: `root_max_size` if a separate home is proposed, unlimited otherwise.
  * Desired size: (`root_base_size` + `root_max_size`) / 2
  * Min size: `root_base_size`

* Home volume
  * Max size: unlimited
  * Desired and min sizes: same values than for the root volume.

### RFC: Emulating the LVM-based old proposal with the old settings

> NOTE: to be reviewed and refined

The behavior of the old proposal is completely different depending on the value
of `vm_keep_unpartitioned_region`. If that setting evaluates to true, an
acceptable way to emulate the behavior with no modifications in the current
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

## References

Some fate entries that influenced the old proposal behavior

* [Fate#303594](https://fate.suse.com/303594) - Probable origin of `vm_desired_size`
* [Fate#308490](https://fate.suse.com/308490) - Reason to add `vm_keep_unpartitioned_region`
