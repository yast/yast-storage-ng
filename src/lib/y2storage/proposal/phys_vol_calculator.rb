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

require "y2storage/disk_size"
require "y2storage/planned"

module Y2Storage
  module Proposal
    # Class used by PartitionsDistributionCalculator to find the best
    # distribution of LVM physical volumes.
    class PhysVolCalculator
      # Initialize.
      #
      # @param all_spaces [Array<FreeDiskSpace>] Disk spaces that could
      #     potentially contain physical volumes
      # @param lvm_helper [Proposal::LvmHelper] contains information about the
      #     LVM planned volumes and how to make space for them
      def initialize(all_spaces, lvm_helper)
        @all_spaces = all_spaces
        @lvm_helper = lvm_helper
      end

      # Extended distribution that includes a planned partition for every
      # physical volumes that would be necessary to fulfill the LVM requirements
      #
      # When using LVM, the number of possible distributions increases a lot.
      # For every space in the disk we can decide to place an LVM PV or not.
      # This method explores all the options and finds the best one.
      #
      # NOTE: exploring all the options is computationally expensive. With a
      # dozen of free spaces it would be already too much. If performance
      # becomes a problem, we should limit the options to explore. For example,
      # in partition tables without restrictions (no MBR) we probably don't need
      # to evaluate all the options. Another possible idea is to identify spaces
      # that are equivalent for our purposes and use only one of them.
      #
      # @param distribution [Planned::PartitionsDistribution] initial
      #     distribution
      #
      # @return [Planned::PartitionsDistribution, nil] nil if it's
      #     impossible to allocate all the needed physical volumes
      def add_physical_volumes(distribution)
        best = nil
        all_spaces.permutation.each do |sorted_spaces|
          candidate = processed(distribution, sorted_spaces)
          next unless candidate
          best = candidate if !best || candidate.better_than(best) < 0
        end
        best
      end

    protected

      attr_reader :lvm_helper, :all_spaces

      # Returns a new PartitionsDistribution created by assigning a physical
      # volume to each space, following the given order, until the goal is
      # reached.
      #
      # Returns nil if it's not possible to create a distribution of physical
      # volumes that guarantees the requirements set by lvm_helper.
      #
      # @param distribution [Planned::PartitionsDistribution] initial
      #     distribution
      # @param sorted_spaces [Array<FreeDiskSpace>]
      #
      # @return [Planned::PartitionsDistribution, nil]
      def processed(distribution, sorted_spaces)
        pv_partitions = {}
        missing_size = lvm_helper.missing_space
        result = nil

        sorted_spaces.each do |space|
          available_size = estimated_available_size(space, distribution)
          next if available_size < lvm_helper.min_pv_size

          # The key point that can invalidate a solution is the distribution of
          # partitions among free spaces, not so much the size. So let's start
          # with minimal volumes. We will grow them in the end if the
          # distribution is valid.
          pv_partitions[space] = new_planned_partition
          useful_space = lvm_helper.useful_pv_space(available_size)

          if useful_space < missing_size
            # Still not enough, let's assume we will use the whole space
            missing_size -= useful_space
          else
            # This space is, hopefully, the last one we need to fill.
            # Let's consolidate and check if it was indeed enough
            begin
              result = distribution.add_partitions(pv_partitions)
            rescue
              # Adding PVs in this order leads to an invalid distribution
              return nil
            end
            if potential_lvm_size(result) >= lvm_helper.missing_space
              # We did it!
              adjust_sizes!(result, space)
              adjust_weights!(result)
              break
            else
              # Our estimation was too optimistic. The overhead of logical
              # partitions fooled us. Let's keep trying.
              missing_size -= useful_space
              result = nil
            end
          end
        end

        result
      end

      # Max size for new partition in a given free space, taking into account the
      # restrictions imposed by the distribution
      #
      # If the space is marked as :primary or :logical, this method returns the
      # exact available size. If partition_type is nil there is still a chance
      # of logical overhead. But since it cannot be known in advance, the method
      # returns an optimistic estimation.
      #
      # @param space [FreeDiskSpace]
      # @param distribution [Planned::PartitionsDistribution]
      def estimated_available_size(space, distribution)
        assigned_space = distribution.space_at(space)
        return space.disk_size unless assigned_space

        size = assigned_space.extra_size
        size -= assigned_space.overhead_of_logical if assigned_space.partition_type == :logical
        size
      end

      # Useful LVM space provided by all the physical volumes in a given
      # distribution
      def potential_lvm_size(distribution)
        total = DiskSize.zero
        distribution.spaces.each do |space|
          pv_partition = space.partitions.detect(&:lvm_pv?)
          next unless pv_partition

          usable_size = space.usable_extra_size + pv_partition.min_size
          total += lvm_helper.useful_pv_space(usable_size)
        end
        total
      end

      # Planned partition representing a LVM physical volume with the minimum
      # possible size
      #
      # @return [Planned::Partition]
      def new_planned_partition
        res = Planned::Partition.new(nil)
        res.partition_id = PartitionId::LVM
        res.encryption_password = lvm_helper.encryption_password
        res.min_size = lvm_helper.min_pv_size
        res
      end

      # Adjust the sizes off all the partitions in the distribution that
      # were created to represent a LVM physical volume.
      #
      # @param distribution [Planned::PartitionsDistribution]
      # @param last_disk_space [FreeDiskSpace] the last space that was added by
      #     #processed is not adjusted to fill as much space as possible, but to
      #     match the total LVM requirements (size and max)
      def adjust_sizes!(distribution, last_disk_space)
        missing_size = lvm_helper.missing_space

        distribution.spaces.each do |space|
          pv_partition = space.partitions.detect(&:lvm_pv?)
          next unless pv_partition
          next if space.disk_space == last_disk_space

          usable_size = space.usable_extra_size + pv_partition.min_size
          pv_partition.min_size = usable_size
          pv_partition.max_size = usable_size
          missing_size -= lvm_helper.useful_pv_space(usable_size)
        end

        space = distribution.space_at(last_disk_space)
        pv_partition = space.partitions.detect(&:lvm_pv?)
        pv_size = lvm_helper.real_pv_size(missing_size)
        pv_partition.min_size = pv_size

        other_pvs_size = lvm_helper.missing_space - missing_size
        pv_partition.max_size = lvm_helper.real_pv_size(lvm_helper.max_extra_space - other_pvs_size)
      end

      # Adjust the sizes off all the planned partitions in the distribution that
      # were created to represent a LVM physical volume.
      def adjust_weights!(distribution)
        distribution.spaces.each do |space|
          pv_partition = space.partitions.detect(&:lvm_pv?)
          next unless pv_partition

          other_partitions = space.partitions.reject { |v| v == pv_partition }
          pv_partition.weight = other_partitions.map(&:weight).reduce(0, :+)
          pv_partition.weight = 1 if pv_partition.weight.zero?
        end
      end
    end
  end
end
