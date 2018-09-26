Status
======

Expert Partitioner
------------------

* The current partitioner mimics 1:1 the user interface of the traditional YaST
  Expert Partitioner and basically all the functionality of the old Partitioner
  is available in the new one, including full management of disks, partitions,
  LVM, MD RAID, etc.

* The main difference with the traditional partitioner is that the new one
  doesn't display information about cylinders and sectors. That's an intentional
  change.

* New functionality, like management of Bcache devices and more flexible
  partition setups, is being developed and the UI is being slightly reorganized
  to accomodate those new features.

Storage Proposal during installation
------------------------------------

Basically works in all situations including the four possible combinations of:

* LVM based vs partitions based
* Plain devices vs encrypted with LUKS

There are still some details to improve, that will be refined with each release.

The behavior is different from the old (pre SLE15/Leap 15.0) proposal. The
difference and some discussions about the migration path can be found in
[old_and_new_proposal.md](old_and_new_proposal.md).


AutoYaST custom partitioning
----------------------------

AutoYaST makes it possible to define very flexible partitioning schemas, as
explained in [the corresponding section of its
documentation](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Partitioning).

This repository includes the Ruby classes implementing the creation of partitions,
LVM systems and MD arrays to honor the specification read from an AutoYaST
profile. All the basic situations are supported and verified to work, but some
aspects needs improvement.

* Thin provisioned LVM.
* Support to enforce partition numbers and for some profile attributes.

This module also includes the Ruby classes implementing AutoYaST cloning of the
system, i.e. creating a `partitioning` section of the AutoYaST profile that
matches the current system. All the devices (partitions, LVM, MD arrays, etc.)
are correctly exported. The generated profile is fully backwards compatible, 
although some corner cases may present problems in that regard.

Miscellaneous
-------------

Many other YaST modules needed adaptation to use yast-storage-ng instead
of yast-storage. During that adaptation, some shortcuts were taken for some
modules which means they will need to be revisited in the future. All those
shortcuts are documented in the [Installer Hacks](doc/installer-hacks.md)
document.
