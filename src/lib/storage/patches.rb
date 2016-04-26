#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

#
# add some useful methods to libstorage-ng objects
#
# Methods added here are expected to be implemented finally in libstorage-ng and
# this file to be removed.
#

require "storage"

module Storage
  # patch libstorage-ng class
  class Disk
    def inspect
      "<Disk \##{sid} #{name} #{Yast::Storage::DiskSize.KiB(size_k)}>"
    end

    # FIXME: Arvin promised #partition_table? in libstorage-ng;
    # until then, fake it
    #
    # #partition_table? is needed as directly accessing #partition_table
    # may raise an exception
    def partition_table?
      partition_table ? true : false
    rescue
      false
    end

    # FIXME: The libstorage API for DASD is still not defined, let's assume it
    # will look like this (for mocking purposes)
    def dasd?
      false
    end

    # FIXME: see above
    def dasd_type
      ::Storage::DASDTYPE_NONE
    end

    # FIXME: see above
    def dasd_format
      ::Storage::DASDF_NONE
    end
  end

  # patch libstorage-ng class
  class Partition
    def inspect
      "<Partition \##{sid} #{name} #{Yast::Storage::DiskSize.KiB(size_k)}>"
    end
  end
end
