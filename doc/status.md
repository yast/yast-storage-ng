Status
======


Expert Partitioner
------------------

* Currently there is a prototype with most basic operations for Disks and LVM.

* The prototype will be substituted by a recreation of the current (old)
  partitioner based on the new library.

* In the future (not clear when), a new expert partitioner with a revamped UI
  will be created.


Storage Proposal during installation
------------------------------------

Basically works in all situations including the four possible combinations of:

* LVM based vs partitions based
* Plain devices vs encrypted with LUKS

There are still some details to iron out, like the excessive (even daunting)
amount of information displayed to the user and the lack of good help texts.

The behavior is different from the current proposal, an agreement is needed
regarding how to iron the differences out. See
[old_and_new_proposal.md](old_and_new_proposal.md).


AutoYaST custom partitioning
----------------------------

AutoYaST makes it possible to define very flexible partitioning schemas, as
explained in [the corresponding section of its
documentation](https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Partitioning).
The code supporting that is now placed directly in AutoYaST and based in the
current (old) version of yast2-storage. The plan is to move that responsibility
to this new module in a way it shares as much code as possible with the normal
installation proposal.

The work on that regard has only recently started.


Miscellaneous
-------------

Many other YaST modules need adaptation to start using yast-storage-ng instead
of yast-storage. In order to enable some installation scenarios, some modules
have already been partially adapted taking some shortcuts in the process, which
means they will need to be revisited in the future. All those shortcuts are
documented in the [Installer Hacks](doc/installer-hacks.md) document.
