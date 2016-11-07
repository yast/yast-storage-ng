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
require "y2storage/proposal/phys_vol_distribution"

module Y2Storage
  class Proposal
    # Class representing the distribution of sets of planned volumes into sets
    # of free disk spaces
    class SpaceDistributionCalculator
      include Yast::Logger

      FREE_SPACE_MIN_SIZE = DiskSize.MiB(30)

      def initialize(lvm_size: DiskSize.zero, lvm_max: DiskSize.unlimited)
        @lvm_size = lvm_size
        @lvm_max = lvm_max
      end

      # Best possible distribution, nil if the volumes don't fit
      #
      # If the lvm_size argument is present, the result will include one
      # or several extra planned volumes defining the LVM physical volumes
      # that need to be created in order to reach that size (using lvm_max
      # as limit).
      #
      # @param volumes [PlannedVolumesList]
      # @param spaces [Array<FreeDiskSpace>]
      # @param devicegraph [::Storage::Devicegraph]
      #
      # @return [SpaceDistribution]
      def best_distribution(volumes, spaces, devicegraph)
        log.info "best_for. lvm_size: #{lvm_size}, lvm_max: #{lvm_max}, volumes: #{volumes}"
        # First, make sure the whole attempt makes sense
        return nil if missing_disk_size(volumes, spaces) > DiskSize.zero

        log.info "Selecting the candidate spaces for each volume"
        begin
          disk_spaces_by_vol = candidate_disk_spaces(volumes, spaces)
        rescue NoDiskSpaceError
          return nil
        end

        log.info "Calculate all the possible distributions of volumes into spaces"
        dist_hashes = distribution_hashes(disk_spaces_by_vol, volumes.target)

        # If LVM is being used, the number of possible distributions increases
        # a lot. For every space on every distribution we can decide to place
        # an LVM PV or not. Let's explore all the options.
        if lvm_size > DiskSize.zero
          log.info "Calculate LVM posibilities for each candidate distribution"
          dist_hashes = lvm_distributions(dist_hashes, spaces, lvm_size, lvm_max)
        end

        candidates = dist_hashes.map do |distribution_hash|
          begin
            SpaceDistribution.new(distribution_hash, devicegraph)
          rescue Error
            next
          end
        end

        candidates.compact!
        log.info "Comparing #{candidates.size} distributions"
        result = candidates.sort { |a, b| a.better_than(b) }.first
        log.info "best_for result: #{result}"
        result
      end

      # Additional space that would be needed in order to have a chance of
      # creating a good SpaceDistribution.
      #
      # Used when resizing windows in order to know how much space to remove
      # from the partition. In that case it's an oversimplyfication, because
      # it's not just a matter of size.
      #
      # @param volumes [PlannedVolumesList]
      # @param disk_spaces [Array<FreeDiskSpace>]
      # @return [DiskSize]
      def missing_disk_size(volumes, free_spaces)
        needed_size = volumes.target_disk_size + lvm_size
        available_space = available_space(free_spaces)
        needed_size - available_space
      end

    protected

      attr_reader :lvm_size, :lvm_max

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

      # Returns an extended set of distributions that includes, for each entry
      # of the original array, all the possibilities for adding extra physical
      # volumes
      #
      # NOTE: in partition tables without restrictions (no MS-DOS), we
      # could limit the options we need to explore. Take that into account if
      # perfomance becomes a problem.
      #
      # @param initial_dists [Array<Hash{FreeDiskSpace => PlannedVolumesList}>]
      # @param all_spaces [Array<FreeDiskSpace>]
      # @param lvm_size [DiskSize]
      # @param max_lvm_size [DiskSize]
      # @return [Array<Hash{FreeDiskSpace => PlannedVolumesList}>]
      def lvm_distributions(initial_dists, all_spaces, lvm_size, max_lvm_size)
        initial_dists.each_with_object([]) do |dist_hash, result|
          space_sizes = lvm_space_sizes(all_spaces, dist_hash)
          pv_dists = PhysVolDistribution.all(space_sizes, lvm_size, max_lvm_size)

          pv_dists.each do |pv_dist|
            dist = dup_distribution(dist_hash)
            pv_dist.each_pair do |space, volume|
              dist[space] ||= PlannedVolumesList.new
              add_physical_volume!(dist[space], volume)
            end
            result << dist
          end
        end
      end

      # @see PhysVolDistribution.all
      def lvm_space_sizes(all_spaces, distribution_hash)
        hash_elements = all_spaces.map do |space|
          volumes = distribution_hash[space]
          used_space = if volumes.nil? || volumes.empty?
            DiskSize.zero
          else
            volumes.target_disk_size
          end
          [space, space.disk_size - used_space]
        end
        Hash[hash_elements]
      end

      # Adds a volume representing a PV to a list of volumes, adjusting its
      # properties according to the content of  the list.
      #
      # It modifies both arguments
      #
      # @param volumes [PlannedVolumesList]
      # @param pv_vol [PlannedVolume]
      def add_physical_volume!(volumes, pv_vol)
        pv_vol.weight = volumes.map(&:weight).reduce(0, :+)
        pv_vol.weight = 1 if pv_vol.weight.zero?
        volumes << pv_vol
      end

      # Returns a deep copy of a distribution hash
      def dup_distribution(distribution_hash)
        Hash[distribution_hash.map { |space, vols| [space, vols.dup] }]
      end
    end
  end
end
