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

require "storage"
require "storage/free_disk_space"

module Yast
  module Storage
    module Refinements
      # Refinement for ::Storage::Disk with some commodity methods
      module Disk
        refine ::Storage::Disk do
          # Checks if it's an USB disk
          #
          # @return [Boolean]
          def usb?
            transport == ::Storage::Transport_USB
          end

          # Partitions contained in the disk
          #
          # @return [Array<::Storage::Partition>]
          def all_partitions
            return [] unless partition_table
            partition_table.partitions.to_a
          end

          # Free spaces inside the disk
          #
          # @return [Array<FreeDiskSpace>]
          def free_spaces
            # TODO: Handle completely empty disks (no partition table) as empty space
            return [] unless partition_table
            partition_table.unused_partition_slots.map do |slot|
              FreeDiskSpace.new(self, slot)
            end
          end
        end
      end
    end
  end
end
