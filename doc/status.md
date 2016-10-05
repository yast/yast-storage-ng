
Status
======


Expert Partitioner
------------------

* Just a prototype with most basic operations for Disks and LVM.

* Discussion with usability team not started yet.


Storage Proposal
----------------

Basically works with MS-DOS partition tables.

Missing:

* Handle disks without partition table.
* Propose GPT for EFI.
* LVM.
* LUKS.


Miscellaneous
-------------

The installation workflow can propose a storage setup and commit it to
disk.

Missing:

* Options to influence proposal.
* Calling expert partitioner.
* Slideshow interaction during commit.
* Adaption of yast2-bootloader.
* Adaption of yast2-packages.
* Successful booting of new system.

