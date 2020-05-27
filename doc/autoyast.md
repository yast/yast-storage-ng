# AutoYaST Support in storage-ng

## About this document

This document describes which components are involved and how they cooperate to
create a partitioning proposal for AutoYaST.

## Use Cases Levels

When it comes to partitioning, we can categorize AutoYaST use cases into three
different levels:

1. Automatic partitioning. The user does not care about the partitioning and
   trusts in AutoYaST to do the right thing.
2. Semi-automatic partitioning. The user would like to set some basic settings.
   E.g., a user would like to use LVM but has no idea about how to configure
   devices and partitions.
3. Expert partitioning. The user specifies how the layout should look.
   However, a complete definition is not required, and AutoYaST should propose
   reasonable defaults for missing parts.

## Profile Content

An AutoYaST profile can define two different kinds of storage settings:

* [General settings][1], which allows altering the `partitioning` section of the
  product features and enabling/disabling multipath.
* [Partitioning layout settings][2], which defines how the partitioning should look like
  (partitions, volume groups, RAIDs devices, etc.).

Translating these groups of settings to use cases levels:

* Level 1: no settings at all.
* Level 2: just _general settings_.
* Level 3: _partitioning layout settings_ and, optionally, _general settings_.

## Process Overview

The AutoYaST partitioning process starts in the [storage_auto client][3], which
lives in the `autoyast2-installation` package. This client relies heavily on the
[AutoinstStorage module][4], which is responsible, among other things, of
importing the AutoYaST profile (via the `#Import` method) and performing the
partitioning (`#Write`).

This document focuses on the `#Import` method, which creates a partitioning
proposal and provides libstorage-ng with the desired *devicegraph*. The
following is just a sketch of the steps of the partitioning process (the rest of
the sections contain the details for all of them):

1. The general settings are [imported][5]. It happens before the
   `AutoinstStorage#Import` method is called.
2. The settings are [preprocessed][6]. Currently, the only preprocessing which
   takes place is replacing `device=ask` with a real device name after asking
   the user. Any preprocessing which implies interacting with the user should be
   done at this point.
3. Build the proposed [devicegraph][7]. It is the complicated part, and it
   involves a lot of stuff that is described later.
4. If [any issue][8] is found during step 3, [present][9] it to the user.

The third step is quite generic, and it is completely different depending on the
use case. The [Y2Autoinstall::StorageProposal][10] class decides which approach
to follow:

* If there is no `<partitioning>` section, AutoYaST relies in the
  {Y2Storage::GuidedProposal} class (levels 1 and 2).
* If a `<partitioning>` section exists, AutoYaST applies an specific
  process (level 3).

## Level 1 Procedure

In this case, the user does not specify any partitioning setting, and AutoYaST
is responsible for proposing a sensible layout. Under the hood, AutoYaST
basically relies on the {Y2Storage::GuidedProposal} using the default
configuration for the installation product.

## Level 2 Procedure

With this approach, the user can define some high-level settings and let
AutoYaST build the proposal.

    <general>
      <storage>
        <proposal>
          <lvm config:type="boolean">true</lvm>
        </proposal>
        <start_multipath config:type="boolean">true</start_multipath>
      </storage>
    </general>

The elements in the `proposal` section are merged with those in the product's
control file. It is like adjusting the guided proposal parameters in the regular
installer. However, only a [few of them are supported][11].

## Level 3 procedure

When the profile contains a `partitioning` section, AutoYaST does not use the
guided proposal, but it follows these steps (see {Y2Storage::AutoinstProposal}):

1. Convert the AutoYaST profile --a hash containing nested hashes and
   arrays-- into something better to work with.
2. Associate each `drive` section included in the profile with a real device.
3. Plan for new stuff by creating a set of *planned devices*.
4. Delete unwanted stuff from the devicegraph.
5. Modify the devicegraph according to the list of planned devices.
6. Add devices required to boot if needed.

### Phase one: converting the profile data into proper objects

As you may know, an AutoYaST profile is basically an XML file which is converted
into a complex hash, including nested hashes and arrays. Working with such a
data structure is not convenient at all. For that reason, as a first step, the
partitioning section of the profile is turned into a
{Y2Storage::AutoinstProfile::PartitioningSection} object, which offers a better
API for this use case.

This class does not work in isolation, as each section of the profile is
represented by different classes ({Y2Storage::AutoinstProfile::DriveSection},
{Y2Storage::AutoinstProfile::PartitionSection}, etc.).

As a side note, the {Y2Storage::AutoinstProfile::PartitioningSection} class is
used when cloning a system too. Check the
{Y2Storage::AutoinstProfile::PartitioningSection.new_from_storage} method for
further details.

### Phase two: assigning the drives

The `partitioning` section of the AutoYaST profile is organized into `drives`
containing a list of `partitions` each. The result must honor that organization.
E.g., two partitions that are listed in the same drive will always end up in the
same disk and two partitions in different drives cannot end up sharing the disk.

The matching between a drive and the real disk can be done explicitly in the
profile (using the `device` tag) or can be left for AutoYaST to decide. In the
latter case, the algorithm used by AutoYaST is dead simple: it just tries to use
the first available device that is not explicitly skipped (there is also a
syntax for skipping devices). The documentation states it tries to find a device
that "looks reasonable" but, in reality, it just uses whatever is not skipped,
with no optimization in place or even without checking if the device is big
enough.

The relationship between profile and real drives is kept in an instance of
{Y2Storage::Proposal::AutoinstDrivesMap}.

### Phase three: planning new stuff

With the drives map in-place, the profile information can already be used to
create {Y2Storage::Planned::Device} objects. Those objects are meant to contain
information about the devices that will be created or reused. There are
especialized classes for each device: {Y2Storage::Planned::Partition},
{Y2Storage::Planned::LvmLv}, {Y2Storage::Planned::LvmVg},
{Y2Storage::Planned::Md}, {Y2Storage::Planned::Bcache},
{Y2Storage::Planned::StrayBlkDevice}, {Y2Storage::Planned::Nfs} and
{Y2Storage::Planned::Btrfs} for multi-device Btrfs filesystems.

The class responsible for driving this phase is
{Y2Storage::Proposal::AutoinstDevicesPlanner}. Basically, it goes through the
list of drives contained in the profile creating the corresponding planned
devices according to the `type` (`:CT_DISK`, `:CT_LVM`, etc.).

However, each type of drive is processed by a different planner class:

* {Y2Storage::Proposal::AutoinstDiskDevicePlanner} for `:CT_DISK` and
  `CT_DMMULTIPATH` (the latter is deprecated).
* {Y2Storage::Proposal::AutoinstVgPlanner} for `:CT_LVM`.
* {Y2Storage::Proposal::AutoinstMdPlanner} for `:CT_MD`.
* {Y2Storage::Proposal::AutoinstBcachePlanner} for `:CT_BCACHE`.
* {Y2Storage::Proposal::AutoinstNfsPlanner} for `:CT_NFS`.
* {Y2Storage::Proposal::AutoinstBtrfsPlanner} for `:CT_BTRFS`.

### Phase four: deleting old stuff

All delete operations are postponed until the list of planned devices is
ready. The reason is that AutoYaST needs to know which devices are going to be
reused to avoid removing them.

{Y2Storage::Proposal::AutoinstSpaceMaker} is the class responsible for cleaning
up the devicegraph according to the `use` and `initialize` attributes of each
drive section.

### Phase five: adding the planned stuff to the devicegraph

This phase consists on updating the devicegraph to contain the planned
devices. For that purpose, and similarly to the
{Y2Storage::Proposal::AutoinstDevicesPlanner} case, a
{Y2Storage::Proposal::AutoinstDevicesCreator} class exists. It receives the
devicegraph and the list of planned devices.

The logic to create each plan device, however, is splitted into several classes:

* {Y2Storage::Proposal::LvmCreator} for {Y2Storage::Planned::LvmVg}.
* {Y2Storage::Proposal::AutoinstMdCreator} for {Y2Storage::Planned::Md}.
* {Y2Storage::Proposal::AutoinstBcacheCreator} for {Y2Storage::Planned::Bcache}.
* {Y2Storage::Proposal::NfsCreator} for {Y2Storage::Planned::Nfs}.
* {Y2Storage::Proposal::BtrfsCreator} for {Y2Storage::Planned::Btrfs}.

Note that there are no separate classes for {Y2Storage::Planned::Disk} and
{Y2Storage::Planned::StrayBlkDevice}. The logic for that kind of devices lives
in the {Y2Storage::Proposal::AutoinstDevicesCreator} for historical reasons and,
ideally, it should be extracted.

It is worth to mention that, if not enough space is found, AutoYaST will try
to reduce the size of the planned devices to make them fit. Check the
{Y2Storage::Proposal::AutoinstPartitionSize} for further details.

### Phase six: adding boot devices (if needed)

After adjusting the devicegraph to include the list of planned devices, AutoYaST
checks whether the resulting system is bootable. If that's not the case,
AutoYaST will try to add the needed devices to the devicegraph.

{Y2Storage::BootRequirementsChecker} is the class responsible for finding out
whether the system is bootable and determining the missing partitions (if any).

## Issues reporting

It is possible that, given a profile, AutoYaST finds issues when trying to
figure out the partitioning layout. Some of those issues might be severe
enough to stop the installation; in other cases, it just displays a warning.

The {::Installation::AutoinstIssues} module features a
{::Installation::AutoinstIssues::List} class where issues are
registered. {::Installation::AutoinstIssues} contains a set of possible issues -- all
of them are classes which inherit from {::Installation::AutoinstIssues::Issue} --.

[1]: https://doc.opensuse.org/projects/autoyast/#CreateProfile.General.storage "General section documentation"
[2]: https://doc.opensuse.org/projects/autoyast/#CreateProfile.Partitioning "Partitioning documentation"
[3]: https://github.com/yast/yast-autoinstallation/blob/20bf1d0ed6dca9d7bd194308db1baf76fe7312cd/src/clients/storage_auto.rb "storage_auto client"
[4]: https://github.com/yast/yast-autoinstallation/blob/942413b8b54171ec3a79884c9be2138d11ba6803/src/modules/AutoinstStorage.rb "AutoinstStorage module"
[5]: https://github.com/yast/yast-autoinstallation/blob/942413b8b54171ec3a79884c9be2138d11ba6803/src/modules/AutoinstStorage.rb#L75 "AutoinstStorage#import_general_settings"
[6]: https://github.com/yast/yast-autoinstallation/blob/942413b8b54171ec3a79884c9be2138d11ba6803/src/modules/AutoinstStorage.rb#L316 "AutoinstStorage#preprocessed_settings"
[7]: https://github.com/yast/yast-autoinstallation/blob/942413b8b54171ec3a79884c9be2138d11ba6803/src/modules/AutoinstStorage.rb#L251 "AutoinstStorage#build_proposal"
[8]: https://github.com/yast/yast-autoinstallation/blob/942413b8b54171ec3a79884c9be2138d11ba6803/src/modules/AutoinstStorage.rb#L272 "AutoinstStorage#valid_proposal?"
[9]: https://github.com/yast/yast-autoinstallation/blob/942413b8b54171ec3a79884c9be2138d11ba6803/src/modules/AutoinstStorage.rb#L296 "Present issues to the user"
[10]: https://github.com/yast/yast-autoinstallation/blob/942413b8b54171ec3a79884c9be2138d11ba6803/src/lib/autoinstall/storage_proposal.rb "StorageProposal"
[11]: https://github.com/yast/yast-autoinstallation/blob/b3bf9dc19dd0eeb31dd6af566c42af46c0dfe3d4/src/modules/AutoinstStorage.rb#L332 "AutoinstStorage#proposal_settings_from_profile"
