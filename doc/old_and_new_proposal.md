# Changes in the storage proposal approach

This document covers the differences between the storage proposals of
yast-storage and yast-storage-ng, with a brief explanation of how they work and
how both can/must be influenced by the settings coming from `control.xml` and
other sources.

It also includes a proposal to revamp the corresponding section in
`control.xml`, in order to provide more flexibility defining the products
behavior and a better access to all the features of the new storage proposal.

## Settings in yast-storage

Most settings used to influence the behavior of the old yast-storage are read
from the `partitioning` section of `control.xml`, with some settings having a
fallback in `/etc/sysconfig`.

This part of the document presents a brief summary of the structure of that
`partitioning` section. More detailed information can be found at:
 * the
   [control.rnc](https://github.com/yast/yast-installation-control/blob/master/control/control.rnc)
   specification,
 * the [corresponding
   section](https://github.com/yast/yast-installation/blob/962b6b289a051b90c13fa5df45ca6b32147da6c3/doc/control-file.md#partitioning)
   of the official control.xml documentation,
 * the [yast-storage/doc/config.xml.description](https://github.com/yast/yast-storage/blob/master/doc/config.xml.description)
   document which details the settings understood by the proposal.

### Options to influence the storage proposal

The exact meaning of each of the following options can be found in the last of
the above-mentioned documents. The explanation on how every option relates to
the others (which is far from being straightforward) can be found below, in the
section titled "How the old proposal distributes the space".

The whole list of proposal-specific attributes is: `try_separate_home`,
`limit_try_home`, `home_path`, `home_fs`, `root_fs`, `root_space_percent`,
`root_base_size`, `root_max_size`, `proposal_lvm`, `vm_desired_size`,
`vm_home_max_size`, `vm_keep_unpartitioned_region` and
`btrfs_increase_percentage`.

### Options to influence proposal and partitioner 

In addition to the list above, there are two options, related to the usage of
Btrfs for the root filesystem, that are used by the proposal and also by the
expert partitioner when suggesting the default configuration for such
filesystem.

  * `subvolumes`. Optional list of Btrfs subvolumes. If it is missing, a
    hard-coded list is used. If the section is there but empty, no subvolumes
    are created. Each subvolume section has a mandatory `path` and optional
    `copy_on_write` and `archs` elements.
  * `btrfs_default_subvolume`. The default subvolume is not represented by an
    entry in the `subvolumes` list, but with a separate option that specifies only
    its path. The path of the default subvolume is prepended to the path of all
    the other subvolumes in the filesystem, no matter if they come from the
    previous list or are manually added by the user of the partitioner.

### Other general options

The `partitioning` section of `control.xml` goes beyond the configuration of
the proposal's behavior. It also contains some options to influence other
aspect of YaST, mainly the installer.

  * `root_subvolume_read_only`. Whether the installer should set readonly for
    `/` at the end of installation.
  * `proposal_settings_editable`. Whether the user can change the proposal
     settings in the UI.
  * `expert_partitioner_warning`. Whether an extra warning pop-up should be
    displayed if the user enters the expert partitioner during installation.
  * `use_separate_multipath_module`. Whether to call the `multipath` client
     from the yast2-multipath package. If false, the `multipath-simple` client
     from yast2-storage is used.

### Obsolete options

The following options were used by the not longer supported "flexible
partitioning" feature: `prefer_remove`, `remove_special_partitions`,
`partitions`.

## How the old proposal distributes the space

This part of the document explains how the storage proposal works in
yast-storage. The content of this section is inferred from the existing
documentation, some inspection of `StorageProposal.rb` and quite some manual
tests. It may not be 100% accurate, specially since many changes have been
introduced over time.

The explanations are intentionally simplified to keep the focus on the main
topic: the influence of the current settings in the behavior of the proposal
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

## How the new proposal distributes the space

The new proposal uses the following two-steps approach when 
deciding which partitions should be created/deleted/resized and how much
space to assign to every new partition or logical volume.

A first step decides which volumes will be needed. Each volume will originate a
partition or a LV in the second step.

If the new format of `control.xml` is used (see [the specification
document](old_and_new_control.md)), the basic list of planned volumes will be
taken from the `<volumes>` subsection of the control file, except for those
the user explicitly disables. If the legacy format is used, there are always at
least two planned volumes (one for swap and one for root) and potentially
another one for home, based on the user's proposal settings.

In addition to those initial volumes, the proposal can plan more for extra
partitions needed to boot the system.

For each volume, three sizes are specified - the minimum one, the desired one
and the maximum. The maximum size can have the special value "unlimited". In
addition, every volume gets a "weight" (so far, based on the
`root_space_percent` setting).

The second step creates the necessary partitions and logical volumes to make
those planned volumes fit in the disk. It makes a first attempt targeting the
"desired" size. If that fails, it tries again but aiming just for the "minimum"
size. During each attempt, preexisting partitions are resized or deleted
according to four settings that can be influenced by the user. See below.

If more space than the target is freed (or is available from the beginning),
that extra space is distributed among all the volumes. The ratio of space is
decided using the corresponding weights. No volume will grow beyond its maximum
size, even if that means leaving unused space in the disk.

Using LVM doesn't make a big difference. The VG (with its required PVs) is
created to accommodate the size of all the created LVs, although the exact
behavior in that regard can be influenced. See below.

### Making space

Every one of the explained attempts to allocate the partitions or LVM logical
volumes may need to previously free the space used in the disks. Obviously,
that's achieved deleting or resizing existing partitions. The selection of
partitions to resize or delete can be influenced with four settings that are
configurable by the user in every proposal run.

  * Windows delete mode: what to do regarding removal of existing partitions
    hosting a Windows system.
    * Never delete a Windows partition.
    * Only delete the Windows partitions that must be removed in order to make
      the proposal possible.
    * Delete all Windows partitions, even if not needed.
  * Linux delete mode: equivalent but related to partitions that are part of a
    Linux installation (partition id linux, swap, lvm or raid).
  * Others delete mode: the same for all other partitions that don't fit into
    the former two groups.
  * Whether to resize Windows systems if needed

### Creation of LVM structures

Warning: this section describes some optional behaviors that are still not
implemented in yast-storage-ng, although they would be very easy to add to the
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

## Proposed settings for yast-storage-ng

The redesign in the approach and code of the storage proposal explained above
also deserves a revamp of the corresponding section in the `control.xml` file.
This part of the document presents a possible alternative for the `partitioning`
section of the control file. The goal is to provide more flexibility defining
the products behavior and better access to all the features of the new storage
proposal.

In order to fully understand this section and its implications is important to
have read and understood the above section titled "How the new proposal
distributes the space".

### General structure

The new `partitioning` section will still contain the
`root_subvolume_read_only`, `proposal_settings_editable`,
`expert_partitioner_warning` and `use_separate_multipath_module` options
described in this document's subsection "Other general options" at "Settings in
yast-storage". These options will retain their exact form and meaning.

In addition that, there will be two new subsections: `proposal` and `volumes`.

### The `proposal` subsection

The `proposal` subsection will be used to configure some general aspects of the
storage proposal (referenced as "guided setup" in the UI) and will contain the
following options.

  * `lvm`. Whether LVM should be used by default.
  * `encrypt`. Whether encryption should be used by default.
  * `windows_delete_mode`. Default value for the automatic delete mode for
    Windows partitions. It can be `none`, `all` or `ondemand`. For more
    information, see the description of the new proposal above.
  * `linux_delete_mode`. Default value for the automatic delete mode for
    Linux partitions. Again, it can be `none`, `all` or `ondemand`.
  * `other_delete_mode`. Default value for the automatic delete mode for
    other partitions. Once again, it can be `none`, `all` or `ondemand`.
  * `resize_windows`. Default value for the user setting deciding whether to
    resize Windows systems if needed.
  * `lvm_vg_strategy`. If the user decides to use LVM, strategy to decide the
    size of the volume group (and, thus, the number and size of created physical
    volumes). There are three possible values.
    * `use_available`. The VG will be created to use all the available space,
      thus the VG size could be greater than the sum of LVs sizes.
    * `use_needed`. The created VG will match the requirements 1:1, so its size
      will be exactly the sum of all the LVs sizes.
    * `use_vg_size`. The VG will have a predefined size, that could be greater
      than the LVs sizes.
  * `lvm_vg_size`. If `use_vg_size` is specified in the previous option, this
    will specify the predefined size of the LVM volume group.

### The `volumes` subsection

Another new `volumes` subsection will be responsible of specifying the
partitions (or logical volumes if LVM is chosen) to create during the proposal
and also the behavior of the expert partitioner regarding them.

It will be basically a collection of `volume` subsections, each of them with the
options listed here. Having read the "How the new proposal distributes the
space" may be important to fully understand some of them.

  * `mount_point`. Directory where the volume will be mounted in the system.
  * `proposed`. Default value of the user setting deciding whether this volume
    should be created or skipped.
  * `proposed_configurable`. Whether the user can change the previous setting
    in the UI. I.e. whether the user can activate/deactivate the volume. Of
    course, setting `proposed` to false and `proposed_configurable` also to
    false has the same effect than deleting the whole `<volume>` entry.
  * `fstypes`. A collection of acceptable file system types. If no list is
    given, YaST will use a fallback one based on the mount point.
  * `fstype`. Default file system type to format the volume.
  * `desired_size`. Initial size to use in the first proposal attempt.
  * `min_size`. Initial size to use in the second proposal attempt.
  * `max_size`. Maximum size to assign to the volume. It can also contain the
    value "unlimited" (meaning as big as possible). This will be considered the
    default value if the option is not present.
  * `max_size_lvm`. When LVM is used, this option can be used to override the
    value at `max_size`.
  * `weight`. Value used to distribute the extra space (after assigning the
    initial ones) among the volumes.
  * `adjust_by_ram`. Default value for the user setting deciding whether the
    initial and max sizes of each attempt should be adjusted based in the RAM
    size. So far the adaptation consists in ensuring all the sizes are, at
    least, as big as the RAM. In the future, an extra `adjust_by_ram_mode`
    option could be added to allow other approaches.
  * `adjust_by_ram_configurable`. Whether the user can change the previous
    setting in the UI.
  * `fallback_for_min_size`. Mount point of another volume. If the volume being
    defined is disabled, the `min_size` of that another volume will be increased
    by the `min_size` of this disabled volume.
  * `fallback_for_desired_size`. Same than before, but for `desired_size`.
  * `fallback_for_max_size`. Same than before, but for `max_size`.
  * `fallback_for_max_size_lvm`. Same than before, but for `max_size_lvm`.
  * `fallback_for_weight`. Same than before, but for the volume weight.

Some options will only apply if the chosen filesystem type for the volume is
Btrfs, in some cases with the same name and meaning that in the old
`control.xml` format. The main difference is that now the setting will apply to
the volume in which it's included, not necessarily to the root ("/") one. In the
expert partitioner, if a Btrfs filesystem is created and assigned to the mount
point of the volume, these settings will also be used to suggest the filesystem
options.

  * `snapshots`. Default value for the user setting deciding whether snapshots
    should be activated.
  * `snapshots_configurable`. Whether the user can change the previous setting
    in the UI.
  * `snapshots_size`. Similar to `btrfs_increase_percentage` in the
    yast-storage format, but slightly more flexible. If it's a size, the initial
    and maximum sizes for the volume will be increased according if snapshots
    are being used. If it's a number, it will be used as a percentage of the
    original sizes (just like the original `btrfs_increase_percentage`).
  * `subvolumes`. Equivalent to the previous option that used to apply only to
    "/".
  * `btrfs_default_subvolume`. Same than before. NOTE: keeping this as a
    separate setting instead of making it just another subvolume in the list
    above is debatable.

And finally there is an option that deserves a slightly more detailed
explanation.

  * `disable_order`. Volumes with some value here will be disabled (or snapshots
    deactivated) if needed to make the initial proposal. See detailed
    explanation below.

Before any user interaction, an initial proposal with the default settings is
calculated. If YaST is not able to make space for all the volumes required by
those default settings, it will perform new attempts altering the settings. For
that, it will follow the `disable_order` for each volume with that field.

In the first iteration, it will look for the lowest number there. If
`adjust_by_swap` is optional in that volume and enabled, it will disable it. If
that is not enough and snapshots are optional but enabled, it will disable them
and try again (assuming Btrfs is being used). If that's still not enough, it
will disable the whole volume if it's optional.

If that's not enough, it will keep those settings and look for the next volume
with some value in `disable_order` to perform the same operation in a cumulative
fashion.

## Some examples of control file with the new format

This section shows how it would be possible to reproduce the current behavior of
several products via the new proposal and the new suggested format for
`control.xml`. Hopefully, it also illustrates how easy would be to accommodate
changes that are currently very hard or impossible to achieve.

### Current behavior of SLES

Some values are a direct translation of the current `control.xml` and others
(like the relationship with Windows partitions) are inferred from the typical SLES
use case.

```xml
<partitioning>
  <proposal>
    <lvm config:type="boolean">false</default_lvm>
    <encrypt config:type="boolean">false</default_encrypt>
    <windows_delete_mode>all</windows_delete_mode>
    <linux_delete>ondemand</linux_delete_mode>
    <other_delete_mode>ondemand</other_delete_mode>
    <lvm_vg_strategy_mode>use_available</lvm_vg_strategy>
  </proposal>

  <volumes config:type="list">
    <!-- The root filesystem -->
    <volume>
      <mount_point>/</mount_point>
      <fstype>btrfs</fstype>
      <desired_size>5GiB</desired_size>
      <min_size>3GiB</min_size>
      <max_size>10GiB</max_size>
      <weight>35</weight>

      <snapshots config:type="boolean">true</snapshots>
      <snapshots_configurable config:type="boolean">true</snapshots_configurable>
      <snapshots_size>300</snapshots_size>
      <!-- Disable snapshots for / if disabling /home and giving up on
           enlarged swap is not enough -->
      <disable_order>3</disable_order>

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
      <default_fstype>xfs</default_fstype>

      <proposed config:type="boolean">true</proposed>
      <proposed_configurable config:type="boolean">true</proposed_configurable>
      <!-- Disable it in first place if we don't fit in the disk -->
      <disable_order>1</disable_order>

      <desired_size>5GiB</desired_size>
      <min_size>5GiB</min_size>
      <!-- Omitting max_size is also possible, but since we have an explicit
           max_size_lvm and fallback_for_max_size it's more clear to
           include it. -->
      <max_size>unlimited</max_size>
      <max_size_lvm>25GiB</max_size_lvm>
      <weight>55</weight>
      <!-- If this volume is disabled and LVM is not being used, we want
           "/" to become greedy (unlimited max) -->
      <fallback_for_max_size>/</fallback_for_max_size>
    </volume>

    <!-- The swap volume -->
    <volume>
      <mount_point>swap</mount_point>

      <desired_size>2GiB</desired_size>
      <min_size>1GiB</min_size>
      <max_size>2GiB</max_size>
      <weight>10</weight>
      <adjust_by_ram config:type="boolean">true</adjust_by_ram>
      <adjust_by_ram_configurable config:type="boolean">true</adjust_by_ram_configurable>
      <!-- Give up on enlarging to RAM if we still don't fit in the disk
           after disabling separate home -->
      <disable_order>2</disable_order>
    </volume>
  </volumes>
</partitioning>
```

### Current behavior of openSUSE

The `volumes` subsection wouldn't be much different from SLES, with the exception
of some sizes. But the `proposal` one would probably look like this (more MS
Windows friendly).

```xml
<proposal>
  <lvm config:type="boolean">false</lvm>
  <encrypt config:type="boolean">false</encrypt>
  <resize_windows config:type="boolean">true</resize_windows>
  <windows_delete_mode>ondemand</windows_delete_mode>
  <linux_delete_mode>ondemand</linux_delete_mode>
  <other_delete_mode>ondemand</other_delete_mode>
  <lvm_vg_strategy>use_available</lvm_vg_strategy>
</proposal>
```

### Proposed behavior for SLES4SAP

Just a tentative to show the possibilities of the new proposal and serve as an
inspiration. Maybe some aspects don't fit the SAP requirements exactly.

```xml
<partitioning>
  <proposal>
    <lvm config:type="boolean">true</lvm>
    <encrypt config:type="boolean">false</encrypt>
    <windows_delete_mode>all</windows_delete_mode>
    <linux_delete_mode>ondemand</linux_delete_mode>
    <other_delete_mode>ondemand</other_delete_mode>
    <lvm_vg_strategy>use_available</lvm_vg_strategy>
  </proposal>

  <volumes config:type="list">
    <!-- The root filesystem -->
    <volume>
      <mount_point>/</mount_point>
      <!-- Enforce Btrfs for root by not offering any other option -->
      <fstypes>btrfs</fstypes>
      <desired_size>40GiB</desired_size>
      <min_size>30GiB</min_size>
      <max_size>60GiB</max_size>
      <weight>50</weight>
      <!-- Always use snapshots, no matter what -->
      <snapshots config:type="boolean">true</snapshots>
      <snapshots_configurable config:type="boolean">false</snapshots_configurable>

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

      <desired_size>6GiB</desired_size>
      <min_size>4GiB</min_size>
      <max_size>10GiB</max_size>
      <weight>50</weight>
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

### Proposed behavior for CaaSP

Once again, this example is just an approximation to show the possibilities.

```xml
<partitioning>

  <!-- Don't allow the user to use the Guided Setup -->
  <proposal_settings_editable config:type="boolean">false</proposal_settings_editable>
  <!-- Advise the user against using the expert partitioner -->
  <expert_partitioner_warning config:type="boolean">true</expert_partitioner_warning>
  <root_subvolume_read_only config:type="boolean">true</root_subvolume_read_only>

  <!-- All default settings will become final, since the user can't change them -->
  <proposal>
    <lvm config:type="boolean">false</lvm>
    <!-- Delete all previous partitions -->
    <windows_delete_mode>all</windows_delete_mode>
    <linux_delete_mode>all</linux_delete_mode>
    <other_delete_mode>all</other_delete_mode>
  </proposal>

  <volumes config:type="list">
    <!-- The root filesystem -->
    <volume>
      <mount_point>/</mount_point>
      <!-- Default == final, since the user can't change it -->
      <fstype>btrfs</fstype>
      <desired_size>15GiB</desired_size>
      <min_size>10GiB</min_size>
      <max_size>30GiB</max_size>
      <weight>80</weight>
      <!-- Always use snapshots, no matter what -->
      <snapshots config:type="boolean">true</snapshots>
      <snapshots_configurable config:type="boolean">false</snapshots_configurable>

      <btrfs_default_subvolume>@</btrfs_default_subvolume>
      <subvolumes config:type="list">
        <!--
          This would be the same than the <subvolumes> list in the current
          (old) control.xml. Reproducing the whole list doesn't make much sense.
        -->
      </subvolumes>
    </volume>

    <!-- The /var/lib/docker filesystem -->
    <volume>
      <mount_point>/var/lib/docker</mount_point>
      <!-- Default == final, since the user can't change it -->
      <fstype>btrfs</fstype>
      <snapshots config:type="boolean">false</snapshots>
      <snapshots_configurable config:type="boolean">false</snapshots_configurable>

      <!-- No max_size specified, so unlimited -->
      <desired_size>10GiB</desired_size>
      <min_size>10GiB</min_size>
      <weight>20</weight>

      <!-- Give up in a separate partition if the min size doesn't fit -->
      <proposed config:type="boolean">true</proposed>
      <proposed_configurable config:type="boolean">true</proposed_configurable>
      <disable_order>1</disable_order>
      <!-- If this volume is disabled, we want "/" to become greedy
          (unlimited max) -->
      <fallback_for_max_size>/</fallback_for_max_size>
    </volume>

    <!-- No swap partition is defined, so it's never created -->
  </volumes>
</partitioning>
```

## Using the new proposal with the old control.xml format

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

So far, the new format is only a at RFC state, so the old format is always
used and interpreted as explained in this section. In the future, if backwards
compatibility is desired, the presence of the `proposal` or `volumes`
subsections (even if empty) could be used to differentiate which format is
being used.

### Options currently used and ignored

The following settings are currently read by the new proposal and used with
exactly the same meaning.

 * `try_separate_home`
 * `root_space_percent`
 * `proposal_lvm`
 * `btrfs_increase_percentage`
 * `btrfs_default_subvolume`

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

 * `limit_try_home` because the new proposal implements a different mechanism to
   decide when to drop `/home` from the proposal. See the description of the
   mechanism in a previous section.
 * `swap_for_suspend` is not used because the logic to calculate the swap size
   is still not definitive. Moreover, the usefulness of the setting is under
   discussion (Ken suggested a dropping attempt).

The following settings are not read because, as can be inferred from the
sections above, they don't fit the current status of the new algorithm. But they
could be honoured after implementing the alternative modes presented in the
section "Creation of LVM structures".

 * `vm_keep_unpartitioned_region`
 * `vm_desired_size`

### RFC: emulating the partition-based old proposal with the old settings

NOTE: to be reviewed and refined

* Root volume
  * Max size: `root_max_size` if a separate home is proposed, unlimited otherwise.
  * Desired size: (`root_base_size` + `root_max_size`) / 2
  * Min size: `root_base_size`

* Home volume
  * Max size: unlimited
  * Desired and min sizes: same values than for the root volume.

### RFC: Emulating the LVM-based old proposal with the old settings

NOTE: to be reviewed and refined

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
