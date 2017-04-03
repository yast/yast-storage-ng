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
require "y2storage/proposal/proposed_partition"

module Y2Storage
  class Proposal
    # Each one of the spaces contained in a SpaceDistribution
    class AssignedSpace
      extend Forwardable
      using Y2Storage::Refinements::Disk

      # @return [FreeDiskSpace]
      attr_reader :disk_space
      # @return [Array<ProposedPartition>]
      attr_reader :partitions
      # Number of logical partitions that must be created in the space
      attr_accessor :num_logical

      def_delegators :@disk_space, :disk_name, :disk_size, :region, :disk

      def initialize(disk_space, proposed_partitions)
        @disk_space  = disk_space
        @partitions  = proposed_partitions
        @num_logical = 0
        sort_partitions!
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
        disk.as_not_empty do
          @partition_type = if disk.partition_table.extended_possible
            if disk.partition_table.has_extended
              inside_extended? ? :logical : :primary
            end
          else
            :primary
          end
        end
      end

      # Checks if the volumes really fit into the assigned space
      #
      # TODO: We do not check for start_offset. Anyways,
      #  - max_start_offset is usually a soft requirements (it may still work)
      #  - the chances of having 2 volumes with max_start_offset in the same
      #    free space are very low
      def valid?
        if usable_size >= ProposedPartition.disk_size(partitions, rounding: min_grain)
          return true
        end
        # At first sight, there is no enough space, but maybe enforcing some
        # order...
        !enforced_last.nil?
      end

      # Space that will remain unused (wasted) after creating the partitions
      #
      # @return [DiskSize]
      def unused
        max = ProposedPartition.max_disk_size(partitions)
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
        disk_size - ProposedPartition.disk_size(partitions, rounding: min_grain)
      end

      # Usable space available in addition to the target, taking into account
      # the overhead introduced by data structures
      #
      # @see #usable_size
      # @return [DiskSize]
      def usable_extra_size
        usable_size - ProposedPartition.disk_size(partitions)
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
        "#<AssignedSpace disk_space=#{disk_space}, partitions=#{partitions}>"
      end

    protected

      # Checks whether the disk space is inside an extended partition
      #
      # @return [Boolean]
      def inside_extended?
        space_start = disk_space.region.start
        partitions = disk.all_partitions
        extended = partitions.detect { |p| p.type == Storage::PartitionType_EXTENDED }
        return false unless extended
        extended.region.start <= space_start && extended.region.end > space_start
      end

      def min_grain
        disk_space.disk.min_grain
      end

      # Volumes sorted in the most convenient way in order to create partitions
      # for them.
      def sort_partitions!
        @partitions = partitions_sorted_by_attr(:disk, :max_start_offset)
        last = enforced_last
        return unless last

        @partitions.delete(last)
        @partitions << last
      end

      # Returns the volume that must be placed at the end of a given space in
      # order to make all the volumes in the list fit there.
      #
      # This method only returns something meaningful if the only way to make the
      # volumes fit into the space is ensuring one particular volume will be at
      # the end. That corner case can only happen if the size of the given spaces
      # is not divisible by min_grain.
      #
      # If the volumes fit in any order or if it's impossible to make them fit,
      # the method returns nil.
      #
      # @param size_to_fill [DiskSize]
      # @param min_grain [DiskSize]
      # @return [PlannedVolume, nil]
      def enforced_last
        rounded_up = ProposedPartition.disk_size(partitions, rounding: min_grain)
        # There is enough space to fit with any order
        return nil if usable_size >= rounded_up

        missing = rounded_up - usable_size
        # It's impossible to fit
        return nil if missing >= min_grain

        partitions.detect do |partition|
          target_size = partition.disk_size
          target_size.ceil(min_grain) - missing >= target_size
        end
      end

      def partitions_sorted_by_attr(*attrs, nils_first: false, descending: false)
        partitions.each_with_index.sort do |one, other|
          compare(one, other, attrs, nils_first, descending)
        end.map(&:first)
      end

      # @param one [Array] first element: the volume, second: its original index
      # @param other [Array] same structure than previous one
      def compare(one, other, attrs, nils_first, descending)
        one_vol = one.first
        other_vol = other.first
        result = compare_attr(one_vol, other_vol, attrs.first, nils_first, descending)
        if result.zero?
          if attrs.size > 1
            # Try next attribute
            compare(one, other, attrs[1..-1], nils_first, descending)
          else
            # Keep original order by checking the indexes
            one.last <=> other.last
          end
        else
          result
        end
      end

      # @param one [PlannedVolume]
      # @param other [PlannedVolume]
      def compare_attr(one, other, attr, nils_first, descending)
        one_value = one.send(attr)
        other_value = other.send(attr)
        if one_value.nil? || other_value.nil?
          compare_with_nil(one_value, other_value, nils_first)
        else
          compare_values(one_value, other_value, descending)
        end
      end

      # @param one [PlannedVolume]
      # @param other [PlannedVolume]
      def compare_values(one, other, descending)
        if descending
          other <=> one
        else
          one <=> other
        end
      end

      # @param one [PlannedVolume]
      # @param other [PlannedVolume]
      def compare_with_nil(one, other, nils_first)
        if one.nil? && other.nil?
          0
        elsif nils_first
          one.nil? ? -1 : 1
        else
          one.nil? ? 1 : -1
        end
      end
    end
  end
end
