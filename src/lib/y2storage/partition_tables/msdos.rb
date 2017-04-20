# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "y2storage/storage_class_wrapper"
require "y2storage/partition_tables/base"

module Y2Storage
  module PartitionTables
    # A MBR partition table
    #
    # This is a wrapper for Storage::Msdos
    class Msdos < Base
      wrap_class Storage::Msdos

      # @!attribute minimal_mbr_gap
      #   Minimal possible size of the so-called MBR gap.
      #
      #   @see #mbr_gap
      #
      #   @return [DiskSize]
      storage_forward :minimal_mbr_gap, as: "DiskSize"
      storage_forward :minimal_mbr_gap=

      # Current MBR gap
      #
      # The MBR gap is the space between the end of the MBR and the beginning
      # of the first partition. Often used by the bootloader. There is no
      # equivalent in GPT partition tables (where BIOS boot partitions are
      # used to allocate the bootloader).
      #
      # If there are no partitions nil is returned, meaning "gap not
      # applicable" which is different from "no gap" (i.e. a 0 bytes gap).
      #
      # @return [DiskSize, nil]
      def mbr_gap
        return nil if partitions.empty?

        region1 = partitions.min { |x, y| x.region.start <=> y.region.start }
        region1.region.block_size * region1.region.start
      end
    end
  end
end
