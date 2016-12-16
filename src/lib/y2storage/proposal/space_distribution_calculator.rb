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
require "y2storage/planned_volumes_list"
require "y2storage/proposal/space_distribution"
require "y2storage/proposal/assigned_space"
require "y2storage/proposal/phys_vol_calculator"
require "y2storage/refinements"

module Y2Storage
  class Proposal
    # Class representing the distribution of sets of planned volumes into sets
    # of free disk spaces
    class SpaceDistributionCalculator
      include Yast::Logger
      using Y2Storage::Refinements::Disk

      FREE_SPACE_MIN_SIZE = DiskSize.MiB(30)

      def initialize(lvm_helper)
        @lvm_helper = lvm_helper
      end

      # Best possible distribution, nil if the volumes don't fit
      #
      # If it's necessary to provide LVM space (according to lvm_helper),
      # the result will include one or several extra planned volumes defining
      # the LVM physical volumes that need to be created in order to reach
      # that size (within the max limites provided by lvm_helper).
      #
      # @param volumes [PlannedVolumesList]
      # @param spaces [Array<FreeDiskSpace>]
      #
      # @return [SpaceDistribution]
      def best_distribution(volumes, spaces)
        log.info "Calculating best space distribution for #{volumes}"
        # First, make sure the whole attempt makes sense
        return nil if impossible?(volumes, spaces)

        log.info "Selecting the candidate spaces for each volume"
        begin
          disk_spaces_by_vol = candidate_disk_spaces(volumes, spaces)
        rescue NoDiskSpaceError
          return nil
        end

        log.info "Calculate all the possible distributions of volumes into spaces"
        dist_hashes = distribution_hashes(disk_spaces_by_vol, volumes.target)

        candidates = dist_hashes.map do |distribution_hash|
          begin
            SpaceDistribution.new(distribution_hash)
          rescue Error
            next
          end
        end
        candidates.compact!

        if lvm_helper.missing_space > DiskSize.zero
          log.info "Calculate LVM posibilities for each candidate distribution"
          pv_calculator = PhysVolCalculator.new(spaces, lvm_helper)
          candidates.map! { |dist| pv_calculator.add_physical_volumes(dist) }
        end
        candidates.compact!

        log.info "Comparing #{candidates.size} distributions"
        result = candidates.sort { |a, b| a.better_than(b) }.first
        log.info "best_for result: #{result}"
        result
      end

      # Space that should be freed when resizing an existing partition in
      # order to have a good chance of creating a valid SpaceDistribution
      # (by means of #best_distribution).
      #
      # Used when resizing windows in order to know how much space to remove
      # from the partition, although it's an oversimplyfication because being
      # able to generate a valid distribution is not just a matter of size.
      #
      # @param partition [Storage::Partition] partition to resize
      # @param volumes [PlannedVolumesList] volumes to make space for
      # @param free_spaces [Array<FreeDiskSpace>] all free spaces in the system
      # @return [DiskSize]
      def resizing_size(partition, volumes, free_spaces)
        # We are going to resize this partition only once, so let's assume the
        # worst case:
        #  - several volumes (and maybe one of the new PVs) will be logical
        #  - resizing produces a new space
        #  - the LVM must be spread among all the available spaces
        disk = Storage.to_disk(partition.partitionable)
        needed = volumes.target_reserved_disk_size(disk.min_grain)

        max_logical = max_logical(disk, volumes)
        needed += AssignedSpace.overhead_of_logical(disk) * max_logical

        pvs_to_create = free_spaces.size + 1
        needed += lvm_space_to_make(pvs_to_create)

        needed - available_space(free_spaces)
      end

    protected

      attr_reader :lvm_helper

      # Checks whether there is any chance of producing a valid
      # SpaceDistribution to accomodate the volumes and the missing LVM part
      # in the free spaces
      def impossible?(volumes, free_spaces)
        # Let's assume the best possible case - if we need to create a PV it
        # will be only one
        pvs_to_create = 1
        needed = volumes.target_disk_size + lvm_space_to_make(pvs_to_create)
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

      # Max number of logical partitions that can contain a SpaceDistribution
      # for a given disk and set of volumes
      #
      # @param disk [Storage::Partitionable]
      # @param volumes [PlannedVolumesList]
      # @return [Integer]
      def max_logical(disk, volumes)
        ptable = disk.partition_table
        return 0 unless ptable.extended_possible
        # Worst case, all the volumes that can end up in this disk will do so
        # and will be candidates to be logical
        max_volumes = volumes.select { |v| v.disk.nil? || v.disk == disk.name }
        partitions = max_volumes.size
        # Even worst if we need a logical PV
        partitions += 1 unless lvm_helper.missing_space.zero?
        if ptable.has_extended
          partitions
        else
          SpaceDistribution.partitions_in_new_extended(partitions, ptable)
        end
      end

      def available_space(free_spaces)
        spaces = free_spaces.select { |sp| sp.disk_size >= FREE_SPACE_MIN_SIZE }
        spaces.reduce(DiskSize.zero) { |sum, space| sum + space.disk_size }
      end

      # For each volume in the list, it returns a list of the disk spaces
      # that could potentially host the volume.
      #
      # Of course, each disk space can appear on several lists.
      #
      # @param volumes [PlannedVolumesList]
      # @param free_spaces [Array<FreeDiskSpace>]
      # @return [Hash{PlannedVolume => Array<FreeDiskSpace>}]
      def candidate_disk_spaces(volumes, free_spaces)
        volumes.each_with_object({}) do |volume, hash|
          spaces = free_spaces.select { |space| suitable_disk_space?(space, volume, volumes.target) }
          if spaces.empty?
            log.error "No suitable free space for #{volume}"
            raise NoDiskSpaceError, "No suitable free space for the volume"
          end
          hash[volume] = spaces
        end
      end

      # All possible combinations of spaces and volumes.
      #
      # The result is an array in which each entry represents a potential
      # distribution of volumes into spaces taking into account the
      # restrictions set by disk_spaces_by_vol.
      #
      # @param disk_spaces_by_vol [Hash{PlannedVolume => Array<FreeDiskSpace>}]
      #     which spaces are acceptable for each volume
      # @param target [Symbol] target to initialize all the volume lists
      # @return [Array<Hash{FreeDiskSpace => PlannedVolumesList}>]
      def distribution_hashes(disk_spaces_by_vol, target)
        return [{}] if disk_spaces_by_vol.empty?

        hash_product(disk_spaces_by_vol).map do |combination|
          # combination looks like this
          # {vol1 => space1, vol2 => space1, vol3 => space2 ...}
          group_by_space(combination, target)
        end
      end

      def group_by_space(combination, target)
        combination = inverse_hash(combination)
        combination.each_with_object({}) do |(space, vols), hash|
          hash[space] = PlannedVolumesList.new(vols, target: target)
        end
      end

      def suitable_disk_space?(space, volume, target)
        return false if volume.disk && volume.disk != space.disk_name
        return false if space.disk_size < volume.min_valid_disk_size(target)
        max_offset = volume.max_start_offset
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
    end
  end
end
