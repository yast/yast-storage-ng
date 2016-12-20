#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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
require "y2storage/refinements"

module Y2Storage
  class Proposal
    # Each one of the spaces contained in a SpaceDistribution
    class AssignedSpace
      extend Forwardable
      using Y2Storage::Refinements::Disk

      # @return [FreeDiskSpace]
      attr_reader :disk_space
      # @return [PlannedVolumesList]
      attr_reader :volumes
      # Number of logical partitions that must be created in the space
      attr_accessor :num_logical

      def_delegators :@disk_space, :disk_name, :disk_size, :slot, :disk

      def initialize(disk_space, volumes)
        @disk_space  = disk_space
        @volumes     = volumes
        @num_logical = 0
      end

      # Restriction imposed by the disk and the already existent partitions
      #
      # @return [Symbol, nil]
      #   Spaces with a value of :primary can only contain primary partitions.
      #   Spaces with :logical can only contain logical partitions.
      #   A value of nil means there are no restrictions imposed by the disk
      def partition_type
        @partition_type if @partition_type_calculated

        @partition_type_calculated = true
        @partition_type = if disk.partition_table.extended_possible
          if disk.partition_table.has_extended
            inside_extended? ? :logical : :primary
          end
        else
          :primary
        end
      end

      # Checks if the volumes really fit into the assigned space
      #
      # TODO: We do not check for start_offset. Anyways,
      #  - max_start_offset is usually a soft requirements (it may still work)
      #  - the chances of having 2 volumes with max_start_offset in the same
      #    free space are very low
      def valid?
        return true if usable_size >= volumes.target_disk_size(rounding: min_grain)
        # At first sight, there is no enough space, but maybe enforcing some
        # order...
        !!volumes.enforced_last(usable_size, min_grain)
      end

      # Space that will remain unused (wasted) after creating the partitions
      #
      # @return [DiskSize]
      def unused
        max = volumes.max_disk_size
        max >= usable_size ? 0 : usable_size - max
      end

      # Space available in addition to the target
      #
      # This method is slightly pessimistic. In a quite specific corner case, one
      # of the volumes could be adjusted down to not be divisible by min_grain
      # and then the extra size would be actually sligthly bigger than reported.
      # But being pessimistic is good here because we don't want to enforce that
      # situation.
      # @see PlannedVolumesList#enforced_last
      #
      # @return [DiskSize]
      def extra_size
        disk_size - volumes.target_disk_size(rounding: min_grain)
      end

      # Usable space available in addition to the target, taking into account
      # the overhead introduced by data structures
      #
      # @see #usable_size
      # @return [DiskSize]
      def usable_extra_size
        usable_size - volumes.target_disk_size
      end

      # Space that can be distributed among the planned volumes.
      #
      # Substracts from the total the space that will be used by new data
      # structures, like the EBRs of the planned logical partitions
      # See https://en.wikipedia.org/wiki/Extended_boot_record
      #
      # @return [DiskSize]
      def usable_size
        return disk_size if num_logical.zero?

        logical = num_logical
        # If this space is inside an already existing extended partition,
        # libstorage has already substracted the the overhead of the first EBR.
        logical -= 1 if partition_type == :logical
        disk_size - overhead_of_logical * logical
      end

      # Space consumed by the EBR of one logical partition in a given disk
      # See https://en.wikipedia.org/wiki/Extended_boot_record
      #
      # @param disk [#topology]
      # @return [DiskSize]
      def self.overhead_of_logical(disk)
        DiskSize.B(disk.topology.minimal_grain)
      end

      # Space consumed by the EBR of one logical partition within this space
      #
      # @return [DiskSize]
      def overhead_of_logical
        AssignedSpace.overhead_of_logical(disk)
      end

      def to_s
        "#<AssignedSpace disk_space=#{disk_space}, volumes=#{volumes}>"
      end

    protected

      # Checks whether the disk space is inside an extended partition
      #
      # @return [Boolean]
      def inside_extended?
        space_start = disk_space.slot.region.start
        partitions = disk.partition_table.partitions.to_a
        extended = partitions.detect { |p| p.type == Storage::PartitionType_EXTENDED }
        return false unless extended
        extended.region.start <= space_start && extended.region.end > space_start
      end

      def min_grain
        disk_space.disk.min_grain
      end
    end
  end
end
