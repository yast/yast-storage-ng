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

To be written: links to the various files at doc/
