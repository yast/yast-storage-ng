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

require "yast"
require "storage"
require "y2storage/disk_size"
require "y2storage/planned"
require "y2storage/proposal/phys_vol_calculator"

module Y2Storage
  module Proposal
    # Class to find the optimal distribution of planned partitions into the
    # existing disk spaces
    class PartitionsDistributionCalculator
      include Yast::Logger

      FREE_SPACE_MIN_SIZE = DiskSize.MiB(30)

      def initialize(lvm_helper)
        @lvm_helper = lvm_helper
      end

      # Best possible distribution, nil if the planned partitions don't fit
      #
      # If it's necessary to provide LVM space (according to lvm_helper),
      # the result will include one or several extra planned partitions to host
      # the LVM physical volumes that need to be created in order to reach
      # that size (within the max limites provided by lvm_helper).
      #
      # @param partitions [Array<Planned::Partition>]
      # @param spaces [Array<FreeDiskSpace>]
      #
      # @return [Planned::PartitionsDistribution]
      def best_distribution(partitions, spaces)
        log.info "Calculating best space distribution for #{partitions.inspect}"
        # First, make sure the whole attempt makes sense
        return nil if impossible?(partitions, spaces)

        log.info "Selecting the candidate spaces for each planned partition"
        begin
          disk_spaces_by_part = candidate_disk_spaces(partitions, spaces)
        rescue NoDiskSpaceError
          return nil
        end

        log.info "Calculate all the possible distributions of planned partitions into spaces"
        dist_hashes = distribution_hashes(disk_spaces_by_part)
        candidates = distributions_from_hashes(dist_hashes)

        if lvm_helper.missing_space > DiskSize.zero
          log.info "Calculate LVM posibilities for the #{candidates.size} candidate distributions"
          pv_calculator = PhysVolCalculator.new(spaces, lvm_helper)
          candidates.map! { |dist| pv_calculator.add_physical_volumes(dist) }
        end
        candidates.compact!

        best_candidate(candidates)
      end

      # Space that should be freed when resizing an existing partition in
      # order to have a good chance of creating a valid PartitionsDistribution
      # (by means of #best_distribution).
      #
      # Used when resizing windows in order to know how much space to remove
      # from the partition, although it's an oversimplyfication because being
      # able to generate a valid distribution is not just a matter of size.
      #
      # @param partition [Partition] partition to resize
      # @param planned_partitions [Array<Planned::Partition>] planned
      #     partitions to make space for
      # @param free_spaces [Array<FreeDiskSpace>] all free spaces in the system
      # @return [DiskSize]
      def resizing_size(partition, planned_partitions, free_spaces)
        # We are going to resize this partition only once, so let's assume the
        # worst case:
        #  - several planned partitions (and maybe one of the new PVs) will
        #    be logical
        #  - resizing produces a new space
        #  - the LVM must be spread among all the available spaces
        align_grain = partition.partition_table.align_grain
        needed = DiskSize.sum(planned_partitions.map(&:min), rounding: align_grain)

        disk = partition.partitionable
        max_logical = max_logical(disk, planned_partitions)
        needed += Planned::AssignedSpace.overhead_of_logical(disk) * max_logical

        pvs_to_create = free_spaces.size + 1
        needed += lvm_space_to_make(pvs_to_create)

        # The exact amount of available free space is hard to predict.
        #
        # Resizing can introduce a misaligned free space blob. Take this
        # into account by reducing the free space by the disk's alignment
        # granularity. This is slightly too pessimistic (we could check the
        # alignment) - but good enough.
        #
        # A good example of such a block is the free space at the end of a
        # GPT which is practically guaranteed to be misaligned due to the
        # GPT meta data stored at the disk's end.
        #
        available = [available_space(free_spaces) - align_grain, DiskSize.zero].max

        needed - available
      end

    protected

      attr_reader :lvm_helper

      # Checks whether there is any chance of producing a valid
      # PartitionsDistribution to accomodate the planned partitions and the
      # missing LVM part in the free spaces
      def impossible?(planned_partitions, free_spaces)
        # Let's assume the best possible case - if we need to create a PV it
        # will be only one
        pvs_to_create = 1
        needed = DiskSize.sum(planned_partitions.map(&:min)) + lvm_space_to_make(pvs_to_create)
        needed > available_space(free_spaces)
      end

      # Space that needs to be dedicated to new physical volumes in order to
      # have a chance to calculate an acceptable space distribution. The result
      # depends on the number of PV that would be created, since every PV
      # introduces an overhead.
      #
      # @param new_pvs [Integer] max number of PVs that would be created,
      #     if needed. This is by definition an estimation (you never know the
      #     exact number of PVs until you calculate the space distribution)
      # @return [DiskSize]
      def lvm_space_to_make(new_pvs)
        return DiskSize.zero if lvm_helper.missing_space.zero?
        lvm_helper.missing_space + lvm_helper.useless_pv_space * new_pvs
      end

      # Max number of logical partitions that can contain a
      # PartitionsDistribution for a given disk and set of partitions
      #
      # @param disk [Partitionable]
      # @param planned_partitions [Array<Planned::Partition>]
      # @return [Integer]
      def max_logical(disk, planned_partitions)
        ptable = disk.as_not_empty { disk.partition_table }
        return 0 unless ptable.extended_possible?
        # Worst case, all the partitions that can end up in this disk will do so
        # and will be candidates to be logical
        max_partitions = planned_partitions.select { |v| v.disk.nil? || v.disk == disk.name }
        partitions_count = max_partitions.size
        # Even worst if we need a logical PV
        partitions_count += 1 unless lvm_helper.missing_space.zero?
        if ptable.has_extended?
          partitions_count
        else
          Planned::PartitionsDistribution.partitions_in_new_extended(partitions_count, ptable)
        end
      end

      def available_space(free_spaces)
        spaces = free_spaces.select { |sp| sp.disk_size >= FREE_SPACE_MIN_SIZE }
        spaces.reduce(DiskSize.zero) { |sum, space| sum + space.disk_size }
      end

      # For each planned partition, it returns a list of the disk spaces
      # that could potentially host it.
      #
      # Of course, each disk space can appear on several lists.
      #
      # @param planned_partitions [Array<Planned::Partition>]
      # @param free_spaces [Array<FreeDiskSpace>]
      # @return [Hash{Planned::Partition => Array<FreeDiskSpace>}]
      def candidate_disk_spaces(planned_partitions, free_spaces)
        planned_partitions.each_with_object({}) do |partition, hash|
          spaces = free_spaces.select { |space| suitable_disk_space?(space, partition) }
          if spaces.empty?
            log.error "No suitable free space for #{partition}"
            raise NoDiskSpaceError, "No suitable free space for the planned partition"
          end
          hash[partition] = spaces
        end
      end

      # All possible combinations of spaces and planned partitions.
      #
      # The result is an array in which each entry represents a potential
      # distribution of partitions into spaces taking into account the
      # restrictions set by disk_spaces_by_partition.
      #
      # @param disk_spaces_by_partition [Hash{Planned::Partition => Array<FreeDiskSpace>}]
      #     which spaces are acceptable for each planned partition
      # @return [Array<Hash{FreeDiskSpace => <Planned::Partition>}>]
      def distribution_hashes(disk_spaces_by_partition)
        return [{}] if disk_spaces_by_partition.empty?

        hash_product(disk_spaces_by_partition).map do |combination|
          # combination looks like this
          # {partition1 => space1, partition2 => space1, partition3 => space2 ...}
          inverse_hash(combination)
        end
      end

      def suitable_disk_space?(space, partition)
        return false if partition.disk && partition.disk != space.disk_name
        return false if space.disk_size < partition.min_size
        max_offset = partition.max_start_offset
        return false if max_offset && space.start_offset > max_offset
        true
      end

      # Cartesian product (that is, all the possible combinations) of hash
      # whose values are arrays.
      #
      # @example
      #   hash = {
      #     vol1: [:space1, :space2],
      #     vol2: [:space1],
      #     vol3: [:space2, :space3]
      #   }
      #   hash_product(hash) #=>
      #   # [
      #   #  {vol1: :space1, vol2: :space1, vol3: :space2},
      #   #  {vol1: :space1, vol2: :space1, vol3: :space3},
      #   #  {vol1: :space2, vol2: :space1, vol3: :space2},
      #   #  {vol1: :space2, vol2: :space1, vol3: :space3}
      #   # ]
      #
      # @param hash [Hash{Object => Array}]
      # @return [Array<Hash>]
      def hash_product(hash)
        keys = hash.keys
        # Ensure same order
        arrays = keys.map { |key| hash[key] }
        product = arrays[0].product(*arrays[1..-1])
        product.map { |p| Hash[keys.zip(p)] }
      end

      # Inverts keys and values of a hash
      #
      # @example
      #   hash = {vol1: :space1, vol2: :space1, vol3: :space2}
      #   inverse_hash(hash) #=> {space1: [:vol1, :vol2], space2: [:vol3]}
      #
      # @return [Hash] original values as keys and arrays of original
      #     keys as values
      def inverse_hash(hash)
        hash.each_with_object({}) do |(key, value), out|
          out[value] ||= []
          out[value] << key
        end
      end

      # Transforms a set of hashes containing tentative partition distributions
      # into proper {Planned::PartitionsDistribution} objects.
      #
      # Hashes describing invalid distributions are discarded, so the resulting
      # array can have less elements than the original list.
      #
      # @param dist_hashes [Array<Hash{FreeDiskSpace => Array<Planned::Partition>}>]
      # @return [Array<Planned::PartitionsDistribution>]
      def distributions_from_hashes(dist_hashes)
        dist_hashes.each_with_object([]) do |distribution_hash, array|
          begin
            dist = Planned::PartitionsDistribution.new(distribution_hash)
          rescue Error
            next
          end
          array << dist
        end
      end

      # Best partitions distribution
      #
      # @param candidates [Array<Planned::PartitionsDistribution>]
      # @return [Planned::PartitionsDistribution]
      def best_candidate(candidates)
        log.info "Comparing #{candidates.size} distributions"
        result = candidates.sort { |a, b| a.better_than(b) }.first
        log.info "best_for result: #{result}"
        result
      end
    end
  end
end
