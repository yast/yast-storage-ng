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
require "y2storage/proposal/assigned_space"
require "y2storage/refinements/devicegraph_lists"

module Y2Storage
  class Proposal
    # Class representing the distribution of sets of planned volumes into sets
    # of free disk spaces
    class SpaceDistribution
      using Refinements::DevicegraphLists

      include Yast::Logger

      FREE_SPACE_MIN_SIZE = DiskSize.MiB(30)

      # @return [Array<AssignedSpaces>]
      attr_reader :spaces

      # Constructor. Raises an exception when trying to create an invalid
      # distribution.
      # @raise NoDiskSpaceError
      # @raise NoMorePartitionSlotError,
      #
      # @param volumes_by_disk_space [Hash{FreeDiskSpace => PlannedVolumesList}]
      # @param devicegraph [::Storage::Devicegraph]
      def initialize(volumes_by_disk_space, devicegraph)
        @devicegraph = devicegraph
        @spaces = volumes_by_disk_space.map do |disk_space, volumes|
          assigned_space(disk_space, volumes)
        end
        @spaces.freeze
        spaces_by_disk.each do |disk_name, spaces|
          set_partition_types_for(disk_name, spaces)
        end
      end

      # Space wasted by the distribution
      # @return [DiskSize]
      def gaps_total_disk_size
        spaces.map(&:unused).reduce(DiskSize.zero, :+)
      end

      # Number of gaps (unused disk portions) introduced by the distribution
      # @return [Fixnum]
      def gaps_count
        spaces.reject { |s| s.unused.zero? }.size
      end

      # Total space available for the planned volumes
      # @return [DiskSize]
      def spaces_total_disk_size
        spaces.map(&:disk_size).reduce(DiskSize.zero, :+)
      end

      # Comparison method used to sort distributions based on how good are
      # they for installation purposes.
      #
      # @return [Fixnum] -1, 0, 1 like <=>
      def better_than(other)
        # The smallest gaps the better
        res = gaps_total_disk_size <=> other.gaps_total_disk_size
        return res unless res.zero?

        # The fewer gaps the better
        res = gaps_count <=> other.gaps_count
        return res unless res.zero?

        # The less fragmentation the better
        res = spaces.count <=> other.spaces.count
        return res unless res.zero?

        # The biggest installation the better
        res = other.spaces_total_disk_size <=> spaces_total_disk_size
        return res unless res.zero?

        # Just to ensure stable sorting between different executions in case
        # of absolute draw in all previous criteria
        comparable_string <=> other.comparable_string
      end

      def to_s
        spaces_str = spaces.map { |s| s.to_s }.join(", ")
        "#<SpaceDistribution spaces=[#{spaces_str}]>"
      end

      # Deterministic string representation of the space distribution
      #
      # This string is not intended to be human readable, use #to_s for that
      # purpose. The goal of this method is to produce always a consistent
      # string even if the assigned spaces or the lists of volumes that they
      # contain are sorted in a different way for any reason (like a different
      # version of Ruby that iterates hashes in other order).
      #
      # @see #better_than
      # @return [String]
      def comparable_string
        spaces_strings = spaces.map { |space| space_comparable_string(space) }
        spaces_strings.sort.join
      end

    protected

      attr_reader :devicegraph

      # Transforms a FreeDiskSpace and a PlannedVolumesList into a
      # AssignedSpace object if the combination is valid.
      # @raise NoDiskSpaceError otherwise
      #
      # @return [AssignedSpace]
      def assigned_space(disk_space, volumes)
        result = AssignedSpace.new(disk_space, volumes)
        if !result.valid?
          log.error "Invalid assigned space #{result}"
          raise NoDiskSpaceError, "Volumes cannot be allocated into the assigned space"
        end
        result
      end

      # Indexes a list of assigned spaces by disk name
      #
      # @return [Hash{String => Array<AssignedSpace>]
      def spaces_by_disk
        spaces.each_with_object({}) do |space, hash|
          hash[space.disk_name] ||= []
          hash[space.disk_name] << space
        end
      end

      # Sets #partition_type for all the assigned spaces
      #
      # @param disk_name [String]
      # @param spaces [Array<AssignedSpace] spaces allocated in the disk
      def set_partition_types_for(disk_name, spaces)
        disk = ::Storage::Disk.find_by_name(devicegraph, disk_name)
        ptable = disk.partition_table

        if ptable.has_extended
          log.info "There is already a extended partition in the disk"
          (primary, extended) = spaces_by_type_with_extended(spaces, ptable)
        elsif ptable.extended_possible
          log.info "There is no extended partition in the disk"
          (primary, extended) = spaces_by_type_without_extended(spaces, ptable)
        else
          log.info "An extended partition makes no sense in this disk"
          primary = spaces
          extended = []
        end

        primary.each { |s| s.partition_type = :primary }
        extended.each { |s| s.partition_type = :extended }
      end

      # @return [Array<Array<AssignedSpace>>] first element is the list of
      #       primary spaces, second one the list of extended
      def spaces_by_type_with_extended(spaces, ptable)
        (extended, primary) = spaces.partition { |s| space_inside_extended?(s) }
        if too_many_primary?(primary, ptable)
          raise NoMorePartitionSlotError, "Too many primary partitions needed"
        end
        [primary, extended]
      end

      # @return [Array<Array<AssignedSpace>>] first element is the list of
      #       primary spaces, second one the list of extended
      def spaces_by_type_without_extended(spaces, ptable)
        if ptable.num_primary + spaces.size > ptable.max_primary
          log.error "Too sparce: #{ptable.num_primary} + #{spaces.size} > #{ptable.max_primary}"
          raise NoMorePartitionSlotError, "Too sparce distribution"
        end

        if spaces.size == 1
          log.info "No need to impose type restrictions."
          return [], []
        end

        num_partitions = ptable.num_primary + num_partitions(spaces)
        if spaces.size == 1 || num_partitions < ptable.max_primary
          log.info "The total number of partitions will be low. No need to impose type restrictions."
          return [], []
        end

        # At this point, one space will be used to create a new extended
        # partition. The rest should be primary.
        extended = [extended_space(spaces)].compact
        primary = spaces - extended
        if too_many_primary?(primary, ptable)
          raise NoMorePartitionSlotError, "Too many primary partitions needed"
        end

        [primary, extended]
      end

      def too_many_primary?(primary_spaces, ptable)
        # +1 for the extended partition
        num_primary = num_partitions(primary_spaces) + ptable.num_primary + 1
        num_primary > ptable.max_primary
      end

      # Best candidate to hold the extended partition
      #
      # @param [Array<AssignedSpace>] list of possible candidates
      # @return [AssignedSpace]
      def extended_space(spaces)
        # Let's use as extended the space with more volumes (start as
        # secondary criteria just to ensure stable sorting)
        spaces.sort_by { |s| [s.volumes.count, s.slot.region.start] }.last
      end

      # Total number of partitions planned for a given list of spaces
      #
      # @param [Array<AssignedSpace>] list of assigned spaces
      # @return [Fixnum]
      def num_partitions(spaces)
        spaces.map { |s| s.volumes.count }.reduce(0, :+)
      end

      # Checks whether the given space is inside an extended partition
      #
      # @param space [AssignedSpace]
      # @return [Boolean]
      def space_inside_extended?(space)
        space_start = space.slot.region.start
        disks = devicegraph.disks.with(name: space.disk_name)
        extended = disks.partitions.with(type: ::Storage::PartitionType_EXTENDED)
        container = extended.with do |part|
          part.region.start <= space_start && part.region.end > space_start
        end.first
        !container.nil?
      end

      # @see #comparable_string
      def space_comparable_string(space)
        vol_list_string = volume_list_comparable_string(space.volumes)
        "<disk_space=#{space.disk_space}, volumes=#{vol_list_string}>"
      end

      # @see #comparable_string
      def volume_list_comparable_string(vol_list)
        volumes_strings = vol_list.to_a.map { |vol| vol.to_s }.sort
        "<target=#{vol_list.target}, volumes=#{volumes_strings.join}>"
      end

      class << self
        # Best possible distribution, nil if the volumes don't fit
        #
        # @param volumes [PlannedVolumesList]
        # @param disk_spaces [Array<FreeDiskSpace>]
        # @param devicegraph [::Storage::Devicegraph]
        #
        # @return [SpaceDistribution]
        def best_for(volumes, disk_spaces, devicegraph)
          begin
            disk_spaces_by_vol = candidate_disk_spaces(volumes, disk_spaces)
          rescue NoDiskSpaceError
            return nil
          end

          candidates = hash_product(disk_spaces_by_vol).map do |combination|
            lists = inverse_hash(combination)
            lists = lists.each_with_object({}) do |(space, vols), hash|
              hash[space] = PlannedVolumesList.new(vols, target: volumes.target)
            end
            begin
              SpaceDistribution.new(lists, devicegraph)
            rescue Error
              next
            end
          end

          candidates.compact.sort { |a, b| a.better_than(b) }.first
        end

        # Additional space that would be needed in order to maximize the
        # posibilities of creating a good SpaceDistribution.
        #
        # Used when resizing windows in order to know how much space to remove
        # from the partition.
        #
        # This is actually an oversimplyfication, because it's not just a matter
        # of size, so maybe we can rethink this a little bit in the future if
        # needed
        #
        # @param volumes [PlannedVolumesList]
        # @param disk_spaces [Array<FreeDiskSpace>]
        # @return [DiskSize]
        def missing_disk_size(volumes, free_spaces)
          needed_size = volumes.target_disk_size
          available_space = available_space(free_spaces)
          needed_size - available_space
        end

      protected

        def available_space(free_spaces)
          spaces = free_spaces.select do |space|
            space.disk_size >= FREE_SPACE_MIN_SIZE
          end
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
end
