# YaST - rewrite of the storage module

[![Build Status](https://travis-ci.org/yast/yast-storage-ng.svg?branch=master)](https://travis-ci.org/yast/yast-storage-ng)
[![Coverage Status](https://img.shields.io/coveralls/yast/yast-storage-ng/master.svg)](https://coveralls.io/github/yast/yast-storage-ng?branch=master)
[![Code
Climate](https://codeclimate.com/github/yast/yast-storage-ng/badges/gpa.svg)](https://codeclimate.com/github/yast/yast-storage-ng)

yast2-storage-ng is a reimplementation of the YaST storage module
(yast2-storage) based on the also reimplemented library for storage manager
([libstorage-ng](https://github.com/openSUSE/libstorage-ng)).

This module contains essentially three parts:

* Expert Partitioner: A working but very limited prototype capable of actions
  such as creating partitions and filesystems.

* Storage Proposal: Based on the existing storage setup of a system proposes a
  storage layout for a new installation.

* Miscellaneous: Code for the YaST installation workflow and support functions
  for other YaST modules.

The module is entirely unsupported.

## Trying on Running System

If you are brave enough to install this module in a (open)SUSE system, despite
the facts that **is not supported and can produce data loss**, you can perform
the following steps (as root):

```bash
# Repository for Tumbleweed/Factory, adjust this line if using other distribution
zypper ar http://download.opensuse.org/repositories/YaST:/storage-ng/openSUSE_Tumbleweed/ libstorage-ng
zypper ref
rpm -e --nodeps libstorage6 libstorage-ruby libstorage-python libstorage-devel libstorage-testsuite
zypper in yast2-storage-ng
```

## Installation of System with Storage-ng

If you are brave enough to install openSUSE Tumbleweed using this module, despite
the facts that **is not supported and can produce data loss**, you can download the latest ISO
image from [build service](http://download.opensuse.org/repositories/YaST:/storage-ng/images/iso/).

Known issues:

- not all functionality implemented ( see Status below )
- disk have to be at least 25GB big
- if there are already btrfs with subvolumes, it have to be wiped before installation
  with `wipefs --all <disk_device>`

## Status

Check the [status](doc/status.md) of already implemented and still missing
functionality.

