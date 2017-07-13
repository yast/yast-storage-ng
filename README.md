# YaST - rewrite of the storage module

[![Build Status](https://travis-ci.org/yast/yast-storage-ng.svg?branch=master)](https://travis-ci.org/yast/yast-storage-ng)
[![Coverage Status](https://img.shields.io/coveralls/yast/yast-storage-ng/master.svg)](https://coveralls.io/github/yast/yast-storage-ng?branch=master)
[![Code
Climate](https://codeclimate.com/github/yast/yast-storage-ng/badges/gpa.svg)](https://codeclimate.com/github/yast/yast-storage-ng)

yast2-storage-ng is a reimplementation of the YaST storage module
(yast2-storage) based on the also reimplemented library for storage manager
([libstorage-ng](https://github.com/openSUSE/libstorage-ng)).

When finished, this module will contain essentially three parts:

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

This module is entirely unsupported.

## Trying on Running System

If you are brave enough to install this module in a (open)SUSE system, despite
the facts that **is not supported and can produce data loss**, you can perform
the following steps (as root):

```bash
# Repository for Tumbleweed/Factory, adjust this line if using other distribution
zypper ar -f http://download.opensuse.org/repositories/YaST:/storage-ng/openSUSE_Tumbleweed/ libstorage-ng
zypper ref
rpm -e --nodeps libstorage7 libstorage-ruby libstorage-python libstorage-devel libstorage-testsuite
# There might be reported file conflicts between yast2-storage-ng and yast2-storage,
# it should be OK to ignore them.
zypper in yast2-storage-ng
```

Once the package is installed, the YaST Partitioner can be invoked running
`yast2 partitioner` or `yast2 storage`.

It is also possible to run it with a device graph from a file via
`yast2 partitioner_testing <path to file>`. Supported formats are
the [yast2-storage-ng yml
format](https://github.com/yast/yast-storage-ng/blob/master/doc/fake-devicegraphs-yaml-format.md)
and the [libstorage xml format](https://github.com/openSUSE/libstorage-ng).

## Trying the installation process

There are test ISO images [available in the build
service](http://download.opensuse.org/repositories/YaST:/storage-ng/images/iso/)
that can be used to perform an openSUSE Tumbleweed installation using this
module instead of the original yast2-storage. Once again, take into account this
**is not supported and can produce data loss**.

The installation process is the same than a regular openSUSE system. The
following things must be taken into account:

* Not all scenarios work at this point in time (see Status below).
* Some user interfaces can be slightly different.
* The ISO image includes a relatively small selection of software, so choosing
  Gnome or KDE Plasma in the "computer role" screen may not work as expected.

## Status

Check the [status](doc/status.md) of already implemented and still missing
functionality.

