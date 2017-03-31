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

module Y2Storage
  module PartitionTables
    # A slot within a partition table
    #
    # This is a wrapper for Storage::PartitionSlot
    class PartitionSlot
      include StorageClassWrapper
      wrap_class Storage::PartitionSlot

      storage_forward :region, as: "Region"
      storage_forward :nr
      storage_forward :name
      storage_forward :possible?
      storage_forward :primary_slot?, to: :primary_slot
      storage_forward :primary_possible?, to: :primary_possible
      storage_forward :extended_slot?, to: :extended_slot
      storage_forward :extended_possible?, to: :extended_possible
      storage_forward :logical_slot?, to: :logical_slot
      storage_forward :logical_possible?, to: :logical_possible

      def inspect
        nice_size = Y2Storage::DiskSize.B(region.length * region.block_size.to_i)
        "<PartitionSlot #{nr} #{name} #{flags_string} #{nice_size}, #{region.show_range}>"
      end

      alias_method :to_s, :inspect

    private

      # rubocop:disable Metrics/CyclomaticComplexity
      def flags_string
        flags = ""
        flags << "P" if primary_slot?
        flags << "p" if primary_possible?
        flags << "E" if extended_slot?
        flags << "e" if extended_possible?
        flags << "L" if logical_slot?
        flags << "l" if logical_possible?
        flags
      end
      # rubocop:enable all
    end
  end
end
