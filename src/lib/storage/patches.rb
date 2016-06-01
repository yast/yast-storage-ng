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
      "<Disk #{name} #{Yast::Storage::DiskSize.KiB(size_k)}>"
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

    def size_k=(s)
      self.size = s * 1024
    end

    def size_k
      self.size / 1024
    end

  end

  # patch libstorage-ng class
  class Partition
    def inspect
      "<Partition #{name} #{Yast::Storage::DiskSize.KiB(size_k)}, #{region.show_range}>"
    end

    def size_k=(s)
      self.size = s * 1024
    end

    def size_k
      self.size / 1024
    end

  end

  class PartitionSlot
    def inspect
      flags = ""
      flags += "P" if self.primary_slot
      flags += "p" if self.primary_possible
      flags += "E" if self.extended_slot
      flags += "e" if self.extended_possible
      flags += "L" if self.logical_slot
      flags += "l" if self.logical_possible
      nice_size = Yast::Storage::DiskSize.B(region.length * region.block_size)
      "<PartitionSlot #{self.nr} #{self.name} #{flags} #{nice_size}, #{self.region.show_range}>"
    end

    alias to_s inspect
  end

  class Region
    def inspect
      "<Region #{start} - #{self.end}>"
    end

    def show_range
      "#{start} - #{self.end}"
    end

    alias to_s inspect
  end

  class PartitionTable
    def inspect
      i = "<PartitionTable #{self.to_s}[#{self.num_children}] "
      self.partitions.each { |x|
        i += "#{x.inspect}"
      }
      self.unused_partition_slots.each { |x|
        i += "#{x.to_s}"
      }
      i += ">"
    end
  end

  class Device
    def inspect
      "<Device #{self.to_s}>"
    end
  end

  class Topology
    def inspect
      "<Topology ofs #{alignment_offset}, io #{optimal_io_size}, grain #{minimal_grain}/#{calculate_grain}>"
    end
  end

end
