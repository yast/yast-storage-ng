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

The proposal only offers two public classes, `Proposal` and `ProposalSettings`,
that can be used like shown in this example:

```ruby
settings = ProposalSettings.new
# Adjust the default settings if needed
settings.use_separate_home = true
proposal = Proposal.new(settings: settings)
proposal.propose
proposal.devices # => Returns the proposed devicegraph
```

`ProposalSettings` is basically a struct-like class to store several attributes.
All the magic (and complexity) lives in `Proposal`, so let's zoom into it.

Zoom level 1: the proposal steps
--------------------------------

The whole proposal mechanism is divided into two steps, each one of them
implemented in its own class.

In the first place, an instance of `Proposal::VolumesGenerator` is used to
decide which partitions or LVM logical volumes should be created or reused.
Every one of those volumes is represented by an instance of `PlannedVolume`.

All the volumes are contained into an instance of `PlannedVolumesList`. Apart
from offering several convenience methods to deal with the set of volumes, that
list also offers an attribute `#target`, used all along the proposal to know if
the goal at that point in time is to allocate the desired size for all volumes
(`:desired`) or just the minimal one (`:min`). That goal can change over time.

Once the requirements are known, it's time to start allocating those volumes.
That second step is performed by an instance of
`Proposal::DevicegraphGenerator`. Given an initial devicegraph, a list of
planned volumes and a set of proposal settings, it will return a new devicegraph
containing the volumes. First it will try with `:desired` as target. If it fails
to allocate the volumes, it will try again with `:min`, raising an exception if
it fails in that second attempt.

Apart from the two main steps and the classes representing the set of planned
volumes, there is another relevant class in this level of zoom. `DiskAnalyzer`
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

That's why there is a class called `Proposal::SpaceDistribution` that represents
a distribution of volumes alongside all the available free space slots in a
devicegraph. A `Proposal::SpaceDistribution` will only be valid if it honors all
the restrictions imposed by the disks and by the volumes.

So the ultimate goal of a `Proposal::SpaceMaker` is to delete and resize
partitions until it finds a suitable `Proposal::SpaceDistribution`. If at a
given point in time there are several possible distributions, it will return the
best one.

Once the space is generated and the proposal knows how the volumes should be
distributed, it's the turn of `Proposal::PartitionCreator`. One instance of that
class takes the space distribution created in the previous step and makes it
real by creating the partitions and the filesystems.

It's worth mentioning that the previous classes has very little knowledge about
LVM. They mainly work at partition level trusting an instance of
`Proposal::LvmHelper` for everything related to LVM.

The instance of `Proposal::LvmHelper` will take care (indirectly, see below) of
adding the needed physical volumes, if any, to every attempt of
`Proposal::SpaceDistribution`, taking into account all the roundings and
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

An instance of `Proposal::SpaceDistribution` is basically a collection of
`Proposal::AssignedSpace` objects. Every one of those objects relates a free
disk slot with its set of planned volumes and also provides additional
information, like the restrictions imposed by the disk to the partitions
potentially created on that slot (`#partition_type`) or how many of the volumes
should be created as logical partitions to fulfill the distribution
(`#num_logical`).

To calculate the best space distribution for a given disk layout and to decide
how much the existing partitions must be resized, `Proposal::SpaceMaker` relies on
a class called `Proposal::SpaceDistributionCalculator`.

Additionally, to delete the partitions, an operation that may be more complex
that it looks like, the space maker relies on another utility class called
`Proposal::PartitionKiller`.

Last but not least, the class `Proposal::PhysVolDistribution` helps
`Proposal::SpaceDistributionCalculator` and `Proposal::LvmHelper` in the task
of creating a planned volume object for each needed physical volume and adding
those volumes to all the potential space distributions.
