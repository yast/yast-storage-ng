# YaST - rewrite of the storage module

[![Build Status](https://travis-ci.org/yast/yast-storage-ng.svg?branch=master)](https://travis-ci.org/yast/yast-storage-ng)
[![Coverage Status](https://img.shields.io/coveralls/yast/yast-storage-ng/master.svg)](https://coveralls.io/github/yast/yast-storage-ng?branch=master)
[![Code
Climate](https://codeclimate.com/github/yast/yast-storage-ng/badges/gpa.svg)](https://codeclimate.com/github/yast/yast-storage-ng)
[![Inline
Docs](http://inch-ci.org/github/yast/yast-storage-ng.png?branch=master)](http://inch-ci.org/github/yast/yast-storage-ng)

yast2-storage-ng is a reimplementation of the YaST storage module
(yast2-storage) based on the also reimplemented library for storage manager
([libstorage-ng](https://github.com/openSUSE/libstorage-ng)).

This module contains essentially three parts:

* YaST Expert Partitioner: a powerful tool capable of actions such as
  creating partitions and filesystems or configuring LVM and software RAID.

* Storage Proposal: Based on the existing storage setup of a system proposes a
  storage layout for a new installation. Useful in two cases:
    * During a normal installation, offering a user interface to influence and
      inspect the result before it's written to the disks.
    * During auto-installation honoring the `partitioning` section of the
      AutoYaST profile.

* Code for the YaST installation workflow and support functions for the above
  mentioned components and for other YaST modules, organized into the Y2Storage
  Ruby namespace. That includes:
    * A thin wrapper on top of several of the classes provided by the
      [libstorage-ng](https://github.com/openSUSE/libstorage-ng) Ruby bindings,
      like Devicegraph, Disk, etc. Check the libstorage-ng documentation for
      information about the philosophy and general usage and check [the
      documentation of the Y2Storage
      namespace](http://www.rubydoc.info/github/yast/yast-storage-ng/master/Y2Storage)
      for details about the wrapper classes.
    * Additional YaST-specific functionality.

## Status

Check the [status](doc/status.md) of already implemented and still missing
functionality.

## Developer documentation

The `/doc` directory of this repository contains some files with information
that can be very useful as starting point for those willing to modify or
configure this YaST module.

* [y2partitioner_namespaces.md](doc/y2partitioner_namespaces.md) High level view
  on how the code of the Partitioner is organized into classes and namespaces.
* [old_and_new_proposal.md](doc/old_and_new_proposal.md) Comparison of the new
  Guided Proposal with the old method. The document also includes a reference
  about how to configure the Guided Proposal per product/role.
* [proposal.md](doc/proposal.md) High level view on how the code of the Guided
  Proposal is organized into classes and namespaces. Slightly outdated but still
  useful.
* [autoyast.md](doc/autoyast.md) An outdated but still useful document
  explaining how the AutoYaST support was implemented based on the
  infrastructure of the Guided Proposal.
* [boot-requirements.md](doc/boot-requirements.md) An auto-generated formal
  document describing the boot requirements honored by the Guided Proposal, so
  the functionality of the code can be validated by booting experts.
* [boot-partition.md](doc/boot-partition.md) A raw collection of notes taken
  during interviews with several booting experts, used as a reference to
  implement the Guided Proposal.
* [fake-devicegraphs-yaml-format.md](doc/fake-devicegraphs-yaml-format.md) A
  high level view of the format used to represent a libstorage-ng devicegraph in
  the yast-storage-ng test suite.
* [installer-hacks.md](doc/installer-hacks.md) See the status document (linked
  above) for details.
* [designing-proposal-settings-ui.md](doc/designing-proposal-settings-ui.md)
  The document that was used as a base for discussion when defining the user
  interface of the Guided Setup. Kept in the repository just for historic
  reference.
* [sle15_features_in_partitioner.md](doc/sle15_features_in_partitioner.md) The
  document that was used as a base for discussion when adding new features to
  the Partitioner. Kept in the repository just for historic reference.
