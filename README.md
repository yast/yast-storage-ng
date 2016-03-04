# YaST - rewrite of the storage library

[![Build Status](https://travis-ci.org/yast/yast-storage-ng.svg?branch=master)](https://travis-ci.org/yast/yast-storage-ng)
[![Coverage
Status](https://coveralls.io/repos/github/yast/yast-storage-ng/badge.svg?branch=master)](https://coveralls.io/github/yast/yast-storage-ng?branch=master)
[![Code
Climate](https://codeclimate.com/github/yast/yast-storage-ng/badges/gpa.svg)](https://codeclimate.com/github/yast/yast-storage-ng)

yast2-storage-ng is a reimplementation of the YaST storage module (yast2-storage)
based on the also reimplemented library for storage manager (libstorage-ng).

This module includes some working but very limited prototypes capable of actions
such as partitioning or proposing a filesystem layout for installation.

The module is entirely unsupported.

## Installation

If you are brave enough to install this module in a (open)SUSE system, despite
the facts that **is not supported and can produce data loss**, you can perform
the following steps (as root):

```bash
# Repository for Tumbleweed/Factory, adjust this line if using other distribution
zypper ar http://download.opensuse.org/repositories/home:/aschnell:/storage-redesign/openSUSE_Factory/ libstorage-ng
zypper ref
rpm -e --nodeps libstorage6 libstorage-ruby libstorage-python libstorage-devel libstorage-testsuite
zypper in yast2-storage-ng
```
