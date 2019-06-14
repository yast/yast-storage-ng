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

      def initialize(planned_vg = nil)
        @planned_vg = planned_vg
      end

      # Best possible distribution, nil if the planned partitions don't fit
      #
      # If it's necessary to provide LVM space (according to the planned VG),
      # the result will include one or several extra planned partitions to host
      # the LVM physical volumes that need to be created in order to reach
      # that size (within the max limits defined for the planned VG).
      #
      # @param partitions [Array<Planned::Partition>]
      # @param spaces [Array<FreeDiskSpace>]
      #
      # @return [Planned::PartitionsDistribution]
      def best_distribution(partitions, spaces)
        log.info "Calculating best space distribution for #{partitions.inspect}"
        # First, make sure the whole attempt makes sense
        return nil if impossible?(partitions, spaces)

        begin
          dist_hashes = distribute_partitions(partitions, spaces)
        rescue NoDiskSpaceError
          return nil
        end
        candidates = distributions_from_hashes(dist_hashes)

        if lvm?
          log.info "Calculate LVM posibilities for the #{candidates.size} candidate distributions"
          pv_calculator = PhysVolCalculator.new(spaces, planned_vg)
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
      # from the partition.
      #
      # @param partition [Partition] partition to resize
      # @param planned_partitions [Array<Planned::Partition>] planned
      #     partitions to make space for
      # @param free_spaces [Array<FreeDiskSpace>] all free spaces in the system
      # @return [DiskSize]
      def resizing_size(partition, planned_partitions, free_spaces)
        # This is far more complex than "needed_space - current_space" because
        # we really have to find a distribution that is valid.
        #
        # The following code tries to find the minimal valid distribution
        # that would succeed, taking into account that resizing will introduce a
        # new space or make one of the existing spaces grow.

        all_spaces = add_or_mark_growing_space(free_spaces, partition)
        all_planned = all_planned_partitions(planned_partitions)

        begin
          dist_hashes = distribute_partitions(all_planned, all_spaces)
        rescue NoDiskSpaceError
          # If some of the planned partitions cannot live in the available disks,
          # reclaim as much space as possible.
          #
          # FIXME: using the partition size as fallback value in situations
          # where resizing the partition cannot provide a valid solution makes
          # sense because, with the current SpaceMaker algorithm, we will not
          # have another chance of resizing this partition.
          # Revisit this if the global proposal algorithm is changed in the
          # future.
          return partition.size
        end

        missing = missing_size_in_growing_space(dist_hashes, partition.align_grain)
        if missing
          missing + partition.end_overhead
        else
          # Resizing the partition does not provide any valid distribution.
          #
          # FIXME: fallback value, same than above.
          partition.size
        end
      end

    protected

      # When calculating an LVM proposal, this represents the projected "system"
      # volume group to accommodate root and other volumes.
      #
      # Nil if LVM is not involved (partition-based proposal)
      #
      # @return [Planned::LvmVg, nil]
      attr_reader :planned_vg

      # Whether LVM should be taken into account
      #
      # @return [Boolean]
      def lvm?
        !!(planned_vg && planned_vg.missing_space > DiskSize.zero)
      end

      # Checks whether there is any chance of producing a valid
      # PartitionsDistribution to accomodate the planned partitions and the
      # missing LVM part in the free spaces
      def impossible?(planned_partitions, free_spaces)
        needed = DiskSize.sum(planned_partitions.map(&:min))
        log.info "#impossible? - initially needed: #{needed}"
        if lvm?
          # Let's assume the best possible case - if we need to create a PV it
          # will be only one
          pvs_to_create = 1
          needed += lvm_space_to_make(pvs_to_create)
          log.info "#impossible? with LVM - needed: #{needed}"
        end
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
        return DiskSize.zero unless lvm?
        planned_vg.missing_space + planned_vg.useless_pv_space * new_pvs
      end

      # Returns the sum of available spaces
      #
      # @param free_spaces [Array<FreeDiskSpace>] List of free disk spaces
      # @return [DiskSize] Available disk space
      def available_space(free_spaces)
        DiskSize.sum(free_spaces.map(&:disk_size))
      end

      # For each planned partition, it returns a list of the disk spaces
      # that could potentially host it.
      #
      # Of course, each disk space can appear on several lists.
      #
      # @param planned_partitions [Array<Planned::Partition>]
      # @param free_spaces [Array<FreeDiskSpace>]
      # @param raise_if_empty [Boolean] raise a {NoDiskSpaceError} if there is
      #   any planned partition that doesn't fit in any of the spaces
      # @return [Hash{Planned::Partition => Array<FreeDiskSpace>}]
      def candidate_disk_spaces(planned_partitions, free_spaces, raise_if_empty: true)
        planned_partitions.each_with_object({}) do |partition, hash|
          spaces = free_spaces.select { |space| suitable_disk_space?(space, partition) }
          if spaces.empty? && raise_if_empty
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
      # @return [Array<Hash{FreeDiskSpace => Array<Planned::Partition>}>]
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
        return false unless partition_fits_space?(partition, space)
        max_offset = partition.max_start_offset
        return false if max_offset && space.start_offset > max_offset
        true
      end

      # @param partition [Planned::Partition]
      # @param space [FreeDiskSpace]
      #
      # @return [Boolean]
      def partition_fits_space?(partition, space)
        space.growing? ? true : space.disk_size >= partition.min_size
      end

      # All possible combinations of spaces and planned partitions.
      #
      # The result is an array in which each entry represents a potential
      # distribution of partitions into spaces taking into account the
      # restrictions impossed by the planned partitions.
      #
      # All disk spaces are present in the result, including those that cannot
      # host any planned partition.
      #
      # @param partitions [Array<Planned::Partitions>]
      # @param spaces [Array<FreeDiskSpace>]
      # @return [Array<Hash{FreeDiskSpace => Array<Planned::Partition>}>]
      def distribute_partitions(partitions, spaces)
        log.info "Selecting the candidate spaces for each planned partition"
        disk_spaces_by_part = candidate_disk_spaces(partitions, spaces)

        log.info "Calculate all the possible distributions of planned partitions into spaces"
        dist_hashes = distribution_hashes(disk_spaces_by_part)
        add_unused_spaces(dist_hashes, spaces)
        dist_hashes
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

      # Add unused spaces to a distributions hash
      #
      # @param dist_hashes [Array<Hash{FreeDiskSpace => Array<Planned::Partition>}>]
      #   Distribution hashes
      # @param spaces      [Array<FreeDiskSpace>] Free spaces
      # @return [Array<Hash{FreeDiskSpace => Array<Planned::Partition>}>]
      #   Distribution hashes considering all free disk spaces.
      def add_unused_spaces(dist_hashes, spaces)
        spaces_hash = Hash[spaces.product([[]])]
        dist_hashes.map! { |d| spaces_hash.merge(d) }
      end

      # Based on the partition to be resized, sets the FreeDiskSpace#growing? attribute
      # in one of the existing spaces, or adds a new FreeDiskSpace object to the
      # collection if a new space will be created.
      #
      # @see resizing_size
      # @see FreeDiskSpace#growing?
      #
      # @param free_spaces [Array<FreeDiskSpace>] initial list of free spaces in
      #   the system (#growing? returns false for all of them)
      # @param partition [Partition] partition to be resized
      # @return [Array<FreeDiskSpace>] list of free spaces containing a growing one
      #   (added to the list or replacing the original space affected by the resizing)
      def add_or_mark_growing_space(free_spaces, partition)
        result = free_spaces.map do |space|
          if space_right_after_partition?(space, partition)
            new_space = space.dup
            new_space.growing = true
            new_space
          else
            space
          end
        end

        if result.none?(&:growing?)
          # Use partition.region as starting point. After all, the exact start
          # and end positions are not that relevant for our purposes.
          new_space = FreeDiskSpace.new(partition.disk, partition.region)
          new_space.growing = true
          new_space.exists = false
          result << new_space
        end

        result
      end

      # Whether the given free space is located right at the end of the given
      # partition, implying the space will grow if the partition is shrunk.
      #
      # Note that if the space is at the beginning of an extended partition this
      # always returns false, that space can only be reclaimed by deleting
      # partitions, not via resizing.
      #
      # @param free_space [FreeDiskSpace]
      # @param partition [Partition] partition to be resized
      # @return [Boolean]
      def space_right_after_partition?(free_space, partition)
        free_space.disk == partition.disk && free_space.region.start == partition.region.end + 1
      end

      # All planned partitions to consider when resizing an existing partition
      #
      # Used to calculate the worst scenario for resizing a partition with LVM
      # involved.
      #
      # @see #resizing_size
      #
      # @param planned_partitions [Array<Planned::Partition>] original set of
      #   partitions
      # @return [Array<Planned::Partition] original set (in the non-LVM case) or
      #   an extended set including partitions needed for LVM
      def all_planned_partitions(planned_partitions)
        return planned_partitions unless lvm?

        # In the LVM case, assume the worst case - that there will be only
        # one big PV and we have to make room for it as well.
        planned_partitions + [planned_single_pv]
      end

      # Planned partition that would be needed to accumulate all the necessary
      # LVM space in a single physical volume
      #
      # @see #all_planned_partitions
      #
      # @return [Planned::Partition]
      def planned_single_pv
        res = Planned::Partition.new(nil)
        res.min_size = lvm_space_to_make(1)
        res
      end

      # Size that is missing in the space marked as "growing" in order to
      # guarantee that at least one valid distribution is possible.
      #
      # @param dist_hashes [Array<Hash{FreeDiskSpace => Array<Planned::Partition>}>]
      #   Distribution hashes
      # @param align_grain [DiskSize] align grain of the device that hosts the
      #   partition been resized
      #
      # @return [Disksize, nil] nil if it's not possible to guarantee a valid
      #   distribution, no matter how much the growing space is enlarged
      #
      def missing_size_in_growing_space(dist_hashes, align_grain)
        # Group all the distributions based on the partitions assigned
        # to the growing space
        alternatives_for_growing = group_dist_hashes_by_growing_space(dist_hashes)

        # We don't want to know all the valid distributions, we just want to find
        # one valid distribution that minimizes the space to be allocated in
        # growing space.
        #
        # So, first of all, sort all the candidate distribution hashes so we
        # explore first the ones that demands less space in the growing space.
        sorted_keys = alternatives_for_growing.keys.sort do |parts_in_a, parts_in_b|
          compare_planned_parts_sets_size(parts_in_a, parts_in_b, align_grain)
        end

        sorted_keys.each do |parts|
          distros = distributions_from_hashes(alternatives_for_growing[parts])
          next if distros.empty?

          # At least one distribution is valid
          assigned_spaces = distros.map { |i| i.spaces.find { |a| a.disk_space.growing? } }
          missing = assigned_spaces.map(&:total_missing_size).min
          return missing.ceil(align_grain)
        end

        # No valid distributions were found, no matter which planned partitions
        # we assign to the growing space
        nil
      end

      # Compares two sets of planned partitions in order to sort them by total
      # min size, ensuring stable result if both sets have the same total min
      # size
      #
      # @param parts_a [Array<Planned::Partition>]
      # @param parts_b [Array<Planned::Partition>]
      # @param align_grain [DiskSize]
      # @return [Integer] -1 if parts_a is smaller than parts_b, 1 in other case
      def compare_planned_parts_sets_size(parts_a, parts_b, align_grain)
        size_in_a = DiskSize.sum(parts_a.map(&:min), rounding: align_grain)
        size_in_b = DiskSize.sum(parts_b.map(&:min), rounding: align_grain)
        result_by_size = size_in_a <=> size_in_b
        return result_by_size unless result_by_size.zero?

        # Fallback to guarantee stable sorting
        ids_in_a = parts_a.map(&:planned_id).join
        ids_in_b = parts_b.map(&:planned_id).join
        ids_in_a <=> ids_in_b
      end

      # @see missing_size_in_growing_space
      def group_dist_hashes_by_growing_space(dist_hashes)
        result = {}
        dist_hashes.each do |dist|
          key = dist.find { |k, _v| k.growing? }.last
          result[key] ||= []
          result[key] << dist
        end
        result
      end
    end
  end
end
