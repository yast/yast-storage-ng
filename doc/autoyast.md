# AutoYaST Support in storage-ng

## About this document

This document describes which components are involved and how they cooperate in
order to create a partitioning proposal for AutoYaST.

## Use Cases

When it comes to partitioning, AutoYaST use cases can be categorized in three
different levels:

1. Automatic partitioning. The user does not care about the partitioning and
   trusts in AutoYaST to do the right thing.
2. Semi-automatic partitioning. The user would like to set basic some
   settings. E.g., a user would like to use LVM but has no idea how the devices
   are partitions have to be set.
3. Expert partitioning. The user specifies how the layout should look like.
   Anyway, a complete definition is not required and some values could be missing
   (AutoYaST should propose a reasonable default).

## Profile Content

An AutoYaST profile can define two different kind of storage settings:

* [General settings][1], which basically allows to alter the `partitioning` section of the
  product features, although only two options are documented (and thus supported).
* [Partitioning layout][2], which defines how the partitioning should look like (partitions, volume
  groups, etc.).

Translating this to use cases levels:

* Level 1: no settings at all.
* Level 2: just _general settings_.
* Level 3: _partitioning layout settings_ and, optionally, _general settings_.

## Process Overview

The AutoYaST partitioning process starts in the [storage_auto client][3], that
lives in the `autoyast2-installation` package. This client relies heavily on the
[AutoinstStorage module][4] which is responsible, among other things, of
importing the AutoYaST profile (via the `#Import` method) and performing the
partitioning (`#Write`).

This document focuses in the `#Import` method, which creates a partitioning
proposal and provides libstorage-ng with the desired *devicegraph*. The
following is just an sketch of the steps of the partitioning process (the rest
of the sections will dig into the details for all of them):

1. The general settings are [imported][5]. It happens before the
   `AutoinstStorage#Import` method is actually called.
2. The settings are [preprocessed][6]. Currently, the only preprocessing which
   takes place is replacing `device=ask` with a real device name after asking
   the user. Any preprocessing which implies interacting with the user should be
   done at this point.
3. Build the proposed [devicegraph][7]. This is the complex part and it involves a
   lot of stuff that will be described later.
4. If [any issue][8] is found during step 3, [present][9] it to the user.

The third step is quite generic and it is completely different depending on
whether a `partitioning` section is present in the profile or not. The
[Y2Autoinstall::StorageProposal][10] class decides which approach to follow.

If there is no `partitioning` section, AutoYaST simply relies in the
{Y2Storage::GuidedProposal}. Bear in mind that such a proposal can be influenced
by general settings (leading to level 2). Although this process is quite
complex, it is out of the scope of this document.

However, when the profile contains a `partitioning` section, these are the steps:

1. Convert the AutoYaST profile -a hash including nested hashes and arrays-
   into something better to work with.
2. Associate each drive included in the profile with a real drive.
3. Plan for new stuff by creating a set of *planned devices*.
4. Delete unwanted stuff from the devicegraph.
5. Modify the devicegraph according to the list of planned devices.

## The AutoYaST level 3 procedure

### Phase one: converting the profile data into proper objects

As you may know, an AutoYaST profile is basically an XML file which is converted
into a complex hash, including nested hashes and arrays. Working with such a
data structure is not convenient at all so, as a first step, the partitioning
section of the profile is turned into an
{Y2Storage::AutoinstProfile::PartitioningSection} object, which offers a a
better API for this use case.

This class does not work in isolation, as each element of the profile is
represented by a different class ({Y2Storage::AutoinstProfile::DriveSection},
{Y2Storage::AutoinstProfile::PartitionSection}, etc.).

As a side note, the {Y2Storage::AutoinstProfile::PartitioningSection} class is
used when cloning a system too. Check the
{Y2Storage::AutoinstProfile::PartitioningSection.new_from_storage} method for
further details.

### Phase two: assigning the drives

The `partitioning` section of the AutoYaST profile is organized into drives
containing a list of partitions each. The result must honor that organization.
E.g., two partitions that are listed in the same drive will always end up in the
same disk and two partitions in different drives cannot end up sharing the disk.

The matching between a drive and the real disk can be done explicitly in the
profile (using the `device` tag) or can be left for AutoYaST to decide. In the
latter case, the algorithm used by AutoYaST is dead simple - it just tries to
use the first available device that is not explicitly skipped (there is also a
syntax for skipping devices). The documentation states it tries to find a device
that "looks reasonable", but in reality it just uses whatever is not skipped,
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
{Y2Storage::Planned::StrayBlkDevice} and {Y2Storage::Planned::Nfs}.

The class responsible for driving this phase is
{Y2Storage::Proposal::AutoinstDevicesPlanner}. Basically, it goes through the
list of drives contained in the profile creating the corresponding planned
devices according to the `type` (`:CT_DISK`, `:CT_LVM`, etc.).

However, each type of drive is processed by a different planner class:

* {Y2Storage::Proposal::AutoinstDiskDevicePlanner} for `:CT_DISK`.
* {Y2Storage::Proposal::AutoinstVgPlanner} for `:CT_LVM`.
* {Y2Storage::Proposal::AutoinstMdPlanner} for `:CT_MD`.
* {Y2Storage::Proposal::AutoinstBcachePlanner} for `:CT_BCACHE`.
* {Y2Storage::Proposal::AutoinstNfsPlanner} for `:CT_NFS`.

### Phase four: deleting old stuff

All delete operations are postponed until the list of planned devices is
ready. The reason is that AutoYaST needs to know which devices are going to be
reused to avoid removing them.

{Y2Storage::Proposal::AutoinstSpaceMaker} is the class responsible for cleaning
up the devicegraph according to the `use` and `initialize` attributes of each
drive section.

### Phase five: adding the planned stuff to the devicegraph

The last phase consists on updating the devicegraph to contain the planned
devices. For that purpose, and similarly to the
{Y2Storage::Proposal::AutoinstDevicesPlanner} case, a
{Y2Storage::Proposal::AutoinstDevicesCreator} class exists. It receives the
devicegraph and the list of planned devices.

The logic to create each plan device, however, is splitted into several classes:

* {Y2Storage::Proposal::LvmCreator} for {Y2Storage::Planned::LvmVg}.
* {Y2Storage::Proposal::MdCreator} for {Y2Storage::Planned::Md}.
* {Y2Storage::Proposal::BcacheCreator} for {Y2Storage::Planned::Bcache}.
* {Y2Storage::Proposal::NfsCreator} for {Y2Storage::Planned::Nfs}.

Note that there are no separate classes for {Y2Storage::Planned::Disk} and
{Y2Storage::Planned::StrayBlkDevice}. The logic for that kind of devices lives
in the {Y2Storage::Proposal::AutoinstDevicesCreator} for historical reasons and,
ideally, it should be extracted.

## Issues reporting

It is possible that, given a profile, AutoYaST finds issues when trying to
figure out a the partitioning layout. Some of those issues might be serious
enough to stop the installation; in other cases, just displaying a warning could
be the way to go.

The {Y2Storage::AutoinstIssues} module features a
{Y2Storage::AutoinstIssues::List} where are problems are registered. After
trying (successfully or not) to create the proposal, AutoYaST displays the list
of problems (if any) to the user. If any of those issues is serious enough, it
will not allow the user to continue.

{Y2Storage::AutoinstIssues} contains a set of possible issues (all of them
are classes which inherit from {Y2Storage::AutoinstIssues::Issue}).

[1]: https://doc.opensuse.org/projects/autoyast/#CreateProfile.General.storage "General section documentation"
[2]: https://doc.opensuse.org/projects/autoyast/#CreateProfile.Partitioning "Partitioning documentation"
[3]: https://github.com/yast/yast-autoinstallation/blob/20bf1d0ed6dca9d7bd194308db1baf76fe7312cd/src/clients/storage_auto.rb "storage_auto client"
[4]: https://github.com/yast/yast-autoinstallation/blob/75af746a955be0d755e645da41061715329bcd7a/src/modules/AutoinstStorage.rb "AutoinstStorage module"
[5]: https://github.com/yast/yast-autoinstallation/blob/20bf1d0ed6dca9d7bd194308db1baf76fe7312cd/src/modules/AutoinstStorage.rb#L78 "AutoinstStorage#import_general_settings"
[6]: https://github.com/yast/yast-autoinstallation/blob/20bf1d0ed6dca9d7bd194308db1baf76fe7312cd/src/modules/AutoinstStorage.rb#L321 "AutoinstStorage#preprocessed_settings"
[7]: https://github.com/yast/yast-autoinstallation/blob/20bf1d0ed6dca9d7bd194308db1baf76fe7312cd/src/modules/AutoinstStorage.rb#L255 "AutoinstStorage#build_proposal"
[8]: https://github.com/yast/yast-autoinstallation/blob/20bf1d0ed6dca9d7bd194308db1baf76fe7312cd/src/modules/AutoinstStorage.rb#L276 "AutoinstStorage#valid_proposal?"
[9]: https://github.com/yast/yast-autoinstallation/blob/20bf1d0ed6dca9d7bd194308db1baf76fe7312cd/src/modules/AutoinstStorage.rb#L300 "Present issues to the user"
[10]: https://github.com/yast/yast-autoinstallation/blob/20bf1d0ed6dca9d7bd194308db1baf76fe7312cd/src/lib/autoinstall/storage_proposal.rb "StorageProposal"
