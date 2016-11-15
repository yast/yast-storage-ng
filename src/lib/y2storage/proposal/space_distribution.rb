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
require "y2storage/proposal/assigned_space"
require "y2storage/refinements/devicegraph_lists"

module Y2Storage
  class Proposal
    # Class representing the distribution of sets of planned volumes into sets
    # of free disk spaces
    class SpaceDistribution
      using Refinements::DevicegraphLists

      include Yast::Logger

      # @return [Array<AssignedSpace>]
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

      # Total number of volumes included in the distribution
      # @return [Fixnum]
      def volumes_count
        spaces.map { |sp| sp.volumes.size }.reduce(0, :+)
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

        # The fewer physical volumes the better
        res = volumes_count <=> other.volumes_count
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
    end
  end
end
