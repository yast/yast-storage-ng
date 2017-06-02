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
require "y2storage/disk_size"
require "y2storage/planned/assigned_space"
require "y2storage/exceptions"

module Y2Storage
  module Planned
    # Class representing the distribution of sets of planned partitions into
    # sets of free disk spaces
    class PartitionsDistribution
      include Yast::Logger

      # @return [Array<AssignedSpace>]
      attr_reader :spaces

      # Constructor. Raises an exception when trying to create an invalid
      # distribution.
      # @raise NoDiskSpaceError
      # @raise NoMorePartitionSlotError
      #
      # @param partitions_by_disk_space [Hash{FreeDiskSpace => Array<Planned::Partition>}]
      def initialize(partitions_by_disk_space)
        @spaces = partitions_by_disk_space.map do |disk_space, partitions|
          assigned_space(disk_space, partitions)
        end
        @spaces.freeze
        spaces_by_disk.each do |disk, spaces|
          disk.as_not_empty do
            set_num_logical_for(spaces, disk.partition_table)
          end
        end
      end

      # Result of adding more partitions to the existent distribution. Raises an
      # exception when trying to create an invalid distribution.
      # @raise NoDiskSpaceError
      # @raise NoMorePartitionSlotError
      #
      # @param partitions_by_disk_space [Hash{FreeDiskSpace => Planned::Partition}]
      def add_partitions(partitions_by_disk_space)
        partitions = {}
        spaces.each do |space|
          partitions[space.disk_space] = space.partitions.dup
        end
        partitions_by_disk_space.each do |space, partition|
          partitions[space] ||= []
          partitions[space] << partition
        end
        PartitionsDistribution.new(partitions)
      end

      # Assigned space associated to a given free space
      #
      # @param disk_space [FreeDiskSpace]
      # @return [Planned::AssignedSpace, nil]
      def space_at(disk_space)
        spaces.detect { |s| s.disk_space == disk_space }
      end

      # Space wasted by the distribution
      # @return [DiskSize]
      def gaps_total_disk_size
        DiskSize.sum(spaces.map(&:unused))
      end

      # Number of gaps (unused disk portions) introduced by the distribution
      # @return [Fixnum]
      def gaps_count
        spaces.reject { |s| s.unused.zero? }.size
      end

      # Total space available for the planned partitions
      # @return [DiskSize]
      def spaces_total_disk_size
        DiskSize.sum(spaces.map(&:disk_size))
      end

      # Total number of planned partitions included in the distribution
      # @return [Fixnum]
      def partitions_count
        spaces.map { |sp| sp.partitions.size }.reduce(0, :+)
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
        res = partitions_count <=> other.partitions_count
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
        "#<PartitionsDistribution spaces=[#{spaces_str}]>"
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

      # Number of logical partitions that will be allocated in a newly created
      # extended one
      #
      # @param partitions [Integer] total number of partitions to create
      # @param ptable [PartitionTable]
      # @return [Integer]
      def self.partitions_in_new_extended(partitions, ptable)
        free_primary_slots = ptable.max_primary - ptable.num_primary
        return 0 if free_primary_slots >= partitions
        # One slot consumed by the extended partition
        partitions - free_primary_slots + 1
      end

    protected

      # Transforms a FreeDiskSpace and a list of planned partitions into a
      # AssignedSpace object if the combination is valid.
      # @raise NoDiskSpaceError otherwise
      #
      # @return [AssignedSpace]
      def assigned_space(disk_space, partitions)
        result = AssignedSpace.new(disk_space, partitions)
        if !result.valid?
          log.error "Invalid assigned space #{result}"
          raise NoDiskSpaceError, "Volumes cannot be allocated into the assigned space"
        end
        result
      end

      # Indexes the list of assigned spaces by disk
      #
      # @return [Hash{Disk => Array<AssignedSpace>]
      def spaces_by_disk
        spaces.each_with_object({}) do |space, hash|
          hash[space.disk] ||= []
          hash[space.disk] << space
        end
      end

      # Sets #num_logical for all the assigned spaces.
      #
      # @param spaces [Array<AssignedSpace] spaces allocated in the disk
      #     and with a correct value for #partition_type
      # @param ptable [PartitionTable]
      def set_num_logical_for(spaces, ptable)
        # There are only two possible scenarios, either all the spaces got
        # a restricted #partition_type, either none
        if spaces.first.partition_type.nil?
          calculate_num_logical_for(spaces, ptable)
        else
          if too_many_primary?(spaces, ptable)
            raise NoMorePartitionSlotError, "Too many primary partitions needed"
          end
          spaces.each do |space|
            prim = space.partition_type == :primary
            num_logical = prim ? 0 : space.partitions.size
            set_num_logical(space, num_logical)
          end
        end
      end

      # Sets the value of #num_logical for a given assigned space
      #
      # @raise NoDiskSpaceError if the new value causes the partitions to not fit
      def set_num_logical(assigned_space, num)
        assigned_space.num_logical = num
        if !assigned_space.valid?
          log.error "Invalid assigned space #{assigned_space} after adjusting num_logical"
          raise NoDiskSpaceError, "Partitions cannot be allocated into the assigned space"
        end
      end

      def calculate_num_logical_for(spaces, ptable)
        if ptable.num_primary + spaces.size > ptable.max_primary
          log.error "Too sparce: #{ptable.num_primary} + #{spaces.size} > #{ptable.max_primary}"
          raise NoMorePartitionSlotError, "Too sparce distribution"
        end

        logical = PartitionsDistribution.partitions_in_new_extended(num_partitions(spaces), ptable)
        if logical.zero?
          log.info "The total number of partitions will be low. No need of logical ones."
          spaces.each { |s| set_num_logical(s, 0) }
          return
        end

        calculate_num_logical_with_new_extended(spaces, ptable)
      end

      def calculate_num_logical_with_new_extended(spaces, ptable)
        # Try to create as few logical partitions as possible, since they
        # come at a rounding cost
        partitions = num_partitions(spaces)
        num_logical = PartitionsDistribution.partitions_in_new_extended(partitions, ptable)

        if spaces.size == 1
          space = spaces.first
          if !room_for_logical?(space, num_logical)
            raise NoDiskSpaceError, "No space for the logical partitions"
          end
          set_num_logical(space, num_logical)
        end

        # One space will host all the logical partitions (and maybe some primary)
        # The rest should be all primary.
        extended_space = extended_space(spaces, num_logical)
        if extended_space.nil?
          raise NoDiskSpaceError, "No suitable space to create the extended partition"
        end
        primary_spaces = spaces - [extended_space]
        if too_many_primary_with_extended?(primary_spaces, ptable)
          raise NoMorePartitionSlotError, "Too many primary partitions needed"
        end
        set_num_logical(extended_space, num_logical)
        primary_spaces.each { |s| set_num_logical(s, 0) }
      end

      def too_many_primary_with_extended?(primary_spaces, ptable)
        # +1 for the extended partition
        num_primary = num_partitions(primary_spaces) + ptable.num_primary + 1
        num_primary > ptable.max_primary
      end

      def too_many_primary?(spaces, ptable)
        return false unless ptable.extended_possible?
        # If there is no extended partition already, we know that all the
        # assigned spaces of this disk will have a nil partition_type
        # So nothing to check
        return false unless ptable.has_extended?

        primary = spaces.select { |s| s.partition_type == :primary }
        too_many_primary_with_extended?(primary, ptable)
      end

      # Best candidate to hold the logical partition
      #
      # @param spaces [Array<AssignedSpace>] list of possible candidates
      # @param num_logical [Fixnum]
      # @return [AssignedSpace, nil]
      def extended_space(spaces, num_logical)
        spaces = spaces.select { |s| room_for_logical?(s, num_logical) }
        # Let's place the extended in the space with more planned partitions
        # (start as secondary criteria just to ensure stable sorting)
        spaces.sort_by { |s| [s.partitions.count, s.region.start] }.last
      end

      # Total number of partitions planned for a given list of spaces
      #
      # @param spaces [Array<AssignedSpace>] list of assigned spaces
      # @return [Fixnum]
      def num_partitions(spaces)
        spaces.map { |s| s.partitions.count }.reduce(0, :+)
      end

      # @see #comparable_string
      def space_comparable_string(space)
        partitions_string = partitions_comparable_string(space.partitions)
        "<disk_space=#{space.disk_space}, partitions=#{partitions_string}>"
      end

      # @see #comparable_string
      def partitions_comparable_string(partitions)
        partitions_strings = partitions.map { |part| part.to_s }.sort
        "<partitions=#{partitions_strings.join}>"
      end

      # Checks whether an assigned space can host the overhead produced by
      # logical partitions, in addition to its volumes
      #
      # @param assigned_space [AssignedSpace]
      # @param num [Integer] number of partitions that should be logical
      # @return [Boolean]
      def room_for_logical?(assigned_space, num)
        overhead = assigned_space.overhead_of_logical
        assigned_space.extra_size >= overhead * num
      end
    end
  end
end
