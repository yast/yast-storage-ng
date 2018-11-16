The proposal classes
====================

The storage proposal is a rather complex piece of software. This document tries
to provide a high level view of its code organization.

Using the existent code to generate a proposal is very simple and only requires
the usage of two easy to understand classes. The complexity is hidden in those
classes in a layered way - as the reader "zooms" into the solution, more classes
appear. This document will use that layered approach to explain the goal,
responsibility and interactions of each class.

Zoom level 0: the public classes
--------------------------------

The proposal only offers two public classes, `GuidedProposal` and
`ProposalSettings`, that can be used like shown in this example:

```ruby
settings = ProposalSettings.new
# Adjust the default settings if needed
settings.use_separate_home = true
proposal = GuidedProposal.new(settings: settings)
proposal.propose
proposal.devices # => Returns the proposed devicegraph
```

`ProposalSettings` is basically a struct-like class to store several attributes
and to read those attributes from the control file. All the magic (and
complexity) lives in `GuidedProposal`, so let's zoom into it.

Zoom level 1: the proposal steps
--------------------------------

The whole proposal mechanism is divided into two steps, each one of them
implemented in its own class.

In the first place, an instance of `Proposal::PlannedDevicesGenerator` (to be
renamed in the future to `Proposal::DevicesPlanner`) is
used to decide which partitions, LVM logical volumes and Btrfs subvolumes
should be created or reused. Every one of those devices is represented by an
instance of `Planned::Partition`, `Planned::LvmLv` or `Planned::BtrfsSubvolume`,
which offer a relatively flexible specification of the corresponding devices
(e.g. min size, max size and weight, instead of a fixed final size).

Once the requirements are known, it's time to start allocating those devices.
That second step is performed by an instance of
`Proposal::DevicegraphGenerator`. Given an initial devicegraph, a list of
planned devices and a set of proposal settings, it will return a new devicegraph
containing the final devices.

This whole process is potentially repeated twice. In the first attempt, the
instance of `Proposal::PlannedDevicesGenerator` is asked for the desired set of
planned devices, so it will aim for the best possible size for each planned
device. If the instance of `Proposal::DevicegraphGenerator` is not able to
accommodate those planned devices, a second attempt will be performed. On that
second attempt, the device generator will aim for a minimalistic set of planned
devices, reducing the size expectations as much as possible. If the devicegraph
generator also fails to allocate that smaller version of the planned devices, an
exception is raised.

During the installation a first proposal is automatically calculated when
the installer reaches the proposal step. This initial proposal is performed
without user interaction, and it is based on the settings defined for the current
product. There is a specialized class `InititalGuidedProposal` to calculate this
proposal, considering all available devices in the system as possible
candidate devices. Firstly, it will try to make a valid proposal by using each disk
individually. A new disk is not considered until all possible attempts have been carried
out. That is, it will try to disable some settings properties (e.g., snapshots) before
switching to another candidate device. When no proposal was possible by using each
individual device, a last attempt is performed by using all the available devices together.

Apart from the two main steps and the classes representing the set of planned
devices, there is another relevant class in this level of zoom. `DiskAnalyzer`
is used to analyze the initial devicegraph (that is, the content of the disks at
the beginning of the installation process) and to provide useful information about
it to all the other components.

All the components in this level are relatively simple except
`Proposal::DevicegraphGenerator`, so let's zoom into it.

Zoom level 2: steps to generate the devicegraph
-----------------------------------------------

The first step when trying to allocate volumes is to ensure there is enough
space for them. That usually implies deleting or resizing existing partitions in
a sensible way. That's done by an instance of `Proposal::SpaceMaker`.

But finding a place for the volumes is not only a matter of having enough free
space. Two separate slots of 3 GiB provide 6 GiB of free space, but do not make
possible to allocate a single partition of 4 GiB. In an [MBR partition
table](https://en.wikipedia.org/wiki/Master_boot_record#Partition_table_entries),
a single free slot cannot be used to allocate four volumes if there is already
an extended partition in other part of the disk, no matter how big the free slot
is. And so on, the examples are countless.

That's why there is a class called `Planned::PartitionsDistribution` that
represents a distribution of `Planned::Partition` objects alongside all the
available free space slots in a devicegraph. A `Planned::PartitionsDistribution`
will only be valid if it honors all the restrictions imposed by the disks and by
the planned partitions.

So the ultimate goal of a `Proposal::SpaceMaker` is to delete and resize
partitions until it finds a suitable `Planned::PartitionsDistribution`. If at a
given point in time there are several possible distributions, it will return the
best one.

Once the space is generated and the proposal knows how the partitions should be
distributed, it's the turn of `Proposal::PartitionCreator`. One instance of that
class takes the space distribution created in the previous step and makes it
real by creating the partitions and the filesystems.

It's worth mentioning that the previous classes has very little knowledge about
LVM. They mainly work at partition level trusting an instance of
`Proposal::LvmHelper` for everything related to LVM.

The instance of `Proposal::LvmHelper` will take care (indirectly, see below) of
adding the needed physical volumes, if any, to every attempt of
`Planned::PartitionsDistribution`, taking into account all the roundings and
overheads involved in any LVM setup.

Once the instance of `Proposal::PartitionCreator` is done with its job (which
also includes creating the physical volumes contained in the space
distribution), the original instance of `Proposal::LvmHelper` will take care of
creating the volume group, the logical volumes and the filesystems for all the
planned volumes that must reside in LVM.

Zoom level 3: utility classes
-----------------------------

The classes described in the previous zoom level rely on some extra classes to
do their job.

An instance of `Planned::PartitionsDistribution` is basically a collection of
`Planned::AssignedSpace` objects. Every one of those objects relates a free
disk slot with its set of planned partitions and also provides additional
information, like the restrictions imposed by the disk to the partitions
potentially created on that slot (`#partition_type`) or how many of the
partitions should be logical to fulfill the distribution (`#num_logical`).

To calculate the best space distribution for a given disk layout and to decide
how much the existing partitions must be resized, `Proposal::SpaceMaker` relies on
a class called `Proposal::PartitionsDistributionCalculator`.

Additionally, to delete the partitions, an operation that may be more complex
that it looks like, the space maker relies on another utility class called
`Proposal::PartitionKiller`.

Last but not least, the class `Proposal::PhysVolCalculator` helps
`Proposal::PartitionsDistributionCalculator` and `Proposal::LvmHelper` in the
task of creating a planned partition object for each needed physical volume and
adding those volumes to all the potential space distributions.
