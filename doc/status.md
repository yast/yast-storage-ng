Status
======


Expert Partitioner
------------------

* Visualization of disk and partitions, LVM and MD RAID arrays works. Just
  some columns and fields are currently displayed as `TODO`.

* Partial support to manage partitions including delete, create, format and
  encrypt. Not all options work in all situations yet.

* Still not possible to manage LVM or MD arrays (read-only so far).

* The current partitioner mimics 1:1 the user interface of the traditional YaST
  Expert Partitioner. In the future (not clear when), a new expert partitioner
  with a revamped UI will be created.

* The main difference with the traditional partitioner is that the new one
  doesn't display information about cylinders and sectors. That's an intentional
  change.


Storage Proposal during installation
------------------------------------

Basically works in all situations including the four possible combinations of:

* LVM based vs partitions based
* Plain devices vs encrypted with LUKS

There are still some details to improve, like the lack of good help texts.

The behavior is different from the current proposal, an agreement is needed
regarding how to iron the differences out. See
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

* Error handling and reporting to the user.
* Thin provisioned LVM.
* Support to enforce partition numbers and for some profile attributes.
* Automatic adaptation of sizes specified in the profile to match the real
  available space.

This module also includes the Ruby classes implementing AutoYaST cloning of the
system, i.e. creating a `partitioning` section of the AutoYaST profile that
matches the current system. So far, only partitions are correctly exported
(with full backwards compatibility). LVM and MD arrays are ignored so far.

Miscellaneous
-------------

Many other YaST modules need adaptation to start using yast-storage-ng instead
of yast-storage. In order to enable some installation scenarios, some modules
have already been partially adapted taking some shortcuts in the process, which
means they will need to be revisited in the future. All those shortcuts are
documented in the [Installer Hacks](doc/installer-hacks.md) document.
