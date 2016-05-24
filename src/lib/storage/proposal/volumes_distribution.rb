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
require "storage/disk_size"
require "storage/refinements/devicegraph_lists"
require "storage/planned_volumes_list"

module Yast
  module Storage
    class Proposal
      # Class to distribute sets of planned volumes into sets of free
      # disk spaces
      class VolumesDistribution
        using Refinements::DevicegraphLists

        FREE_SPACE_MIN_SIZE = DiskSize.MiB(30)

        attr_reader :volumes_lists

        def initialize(volumes_lists, devicegraph)
          @devicegraph = devicegraph
          @volumes_lists = volumes_lists
          @volumes_lists.freeze
        end

        def spaces
          volumes_lists.keys
        end

        def volumes_for(space)
          volumes_lists[space]
        end

        def type_for(space)
          space_types[space]
        end

        # List of FreeDiskSpaces that will only contain logical (and eventually
        # one extended) partitions, indexed by disk name
        #
        # @return [Hash{String => Array<FreeDiskSpace>}]
        def space_types
          @space_types ||= spaces_by_disk.each_with_object({}) do |(disk_name, spaces), hash|
            disk = ::Storage::Disk.find(devicegraph, disk_name)
            hash.merge!(space_types_for(disk, spaces))
          end
        end

        def valid?(target_size)
          return false unless volumes_lists.all? do |space, vols|
            valid_space?(space, vols, target_size)
          end
          spaces_by_disk.each do |disk_name, spaces|
            disk = ::Storage::Disk.find(devicegraph, disk_name)
            return false unless valid_disk?(disk, spaces)
          end
          true
        end

        def gaps_total_size
          gaps.reduce(DiskSize.zero, :+)
        end

        def gaps_count
          gaps.size
        end

        def spaces_total_size
          spaces.map(&:size).reduce(DiskSize.zero, :+)
        end

        # TODO: ensure stable sorting if two distributions are equally good
        def better_than(other)
          # The smallest gaps the better
          res = gaps_total_size <=> other.gaps_total_size
          return res unless res.zero?

          # The fewer gaps the better
          res = gaps_count <=> other.gaps_count
          return res unless res.zero?

          # The less fragmentation the better
          res = spaces.count <=> other.spaces.count
          return res unless res.zero?

          # The biggest installation the better
          other.spaces_total_size <=> spaces_total_size
        end

      protected

        attr_reader :devicegraph

        def gaps
          @gaps ||= volumes_lists.each_with_object([]) do |(space, volumes), array|
            max = volumes.max_size
            next if max >= space.size
            array << space.size - max
          end
        end

        # Indexes a list of spaces by disk name
        #
        # @return [Hash{String => Array<FreeDiskSpace>]
        def spaces_by_disk
          spaces.each_with_object({}) do |space, hash|
            hash[space.disk_name] ||= []
            hash[space.disk_name] << space
          end
        end

        # Checks which free spaces inside a disk should mandatorily contain only
        # logical (and eventually one extended) partitions.
        #
        # @param disk [::Storage::Disk]
        # @param spaces [Array<FreeDiskSpace] spaces located in the disk
        #
        # @return [Array<FreeDiskSpace>] spaces that should only contain logical
        #     partitions
        def space_types_for(disk, spaces)
          ptable = disk.partition_table

          if ptable.has_extended
            types = {}
            # All spaces must be either extended or primary
            spaces.each do |space|
              types[space] = space_inside_extended?(space) ? :extended : :primary
            end
            return types
          end

          # No extended partitions used, so no restrictions
          return {} unless ptable.extended_possible

          num_partitions = ptable.num_primary + spaces.size
          if num_partitions > ptable.max_primary
            raise NoMorePartitionSlotError
          elsif num_partitions == ptable.max_primary
            # In this case, one space will be used to create a new extended
            # partition. The rest should be primary.
            types = Hash[spaces.map {|s| [s, :primary] }]
            # Let's use the space with more volumes as extended
            spaces_with_vol_count = volumes_lists.map {|space, volumes| [space, volumes.size] }
            spaces_with_vol_count.delete_if { |i| !spaces.include?(i.first) }
            # Region's start as secondary criteria to ensure stable sorting
            spaces_with_vol_count.sort_by! { |i| [i.last, i.first.slot.region.start] }

            types[spaces_with_vol_count.last.first] = :extended
            types
          else
            # We are far from the limit, so no restrictions
            {}
          end
        end

        # Checks whether the given free space is inside an extended partition
        #
        # @param free_space [FreeDiskSpace]
        # @return [Boolean]
        def space_inside_extended?(free_space)
          space_start = free_space.slot.region.start
          disks = devicegraph.disks.with(name: free_space.disk_name)
          extended = disks.partitions.with(type: ::Storage::PartitionType_EXTENDED)
          container = extended.with do |part|
            part.region.start <= space_start && part.region.end > space_start
          end.first
          !!container
        end

        # We could also check for start_offset, but:
        #  - max_start_offset is usually a soft requirements (it may still work)
        #  - the chances of having 2 volumes with max_start_offset in the same
        #    free space are very low
        def valid_space?(space, volumes, target_size)
          space.size >= volumes.send(:"#{target_size}_size")
        end

        def valid_disk?(disk, spaces)
          ptable = disk.partition_table
          return true unless ptable.extended_possible

          begin
            types = space_types_for(disk, spaces)
          rescue NoMorePartitionSlotError
            return false
          end
          primary_spaces = types.select { |space, type| type == :primary }.keys
          primary_count = primary_spaces.map { |space| volumes_for(space).count }.reduce(0, :+)
          primary_count += ptable.num_primary
          primary_count += 1 if ptable.has_extended || types.any? { |_s, type| type == :extended }

          primary_count  <= ptable.max_primary
        end

        class << self

          # Distributes volumes among the free spaces
          #
          # Eventually, we could do different attempts inside the method with
          # different approaches.
          #
          # @raise NoDiskSpaceError if it's not unable to do the matching
          #
          # @param volumes [PlannedVolumesList]
          # @param target_size [Symbol] :desired or :min
          # @param settings [Proposal::Settings] proposal settings
          #
          # @return [Hash{FreeDiskSpace => PlannedVolumesList]
          def best_for(volumes, spaces, devicegraph, target_size)
            begin
              spaces_by_volume = candidate_spaces(volumes, spaces, target_size)
            rescue NoDiskSpaceError
              return nil
            end
          
            candidates = hash_product(spaces_by_volume).map do |combination|
              lists = inverse_hash(combination)
              lists = lists.each_with_object({}) do |(space, volumes), hash|
                hash[space] = PlannedVolumesList.new(volumes)
              end
              VolumesDistribution.new(lists, devicegraph)
            end
            candidates.delete_if { |dist| !dist.valid?(target_size) }

            candidates.sort { |a, b| a.better_than(b) }.first
          end

          # Additional space that would be needed in order to maximize the
          # posibilities of #distribution to succeed.
          #
          # This is tricky, because it's not just a matter of size
          #
          # Used when resizing windows (in order to know how much space to remove
          # from the partition), so maybe we can rethink this a little bit in the
          # future if needed
          def missing_size(volumes, free_spaces, target_size)
            needed_size = volumes.send(:"#{target_size}_size")
            available_space = available_space(free_spaces)
            needed_size - available_space
          end

        protected

          def available_space(free_spaces)
            spaces = free_spaces.select do |space|
              space.size >= FREE_SPACE_MIN_SIZE
            end
            spaces.reduce(DiskSize.zero) { |sum, space| sum + space.size }
          end

=begin
          def useful_spaces(free_spaces, volumes)
            if settings.use_lvm
              free_spaces.select do |space|
                space.size >= FREE_SPACE_MIN_SIZE
              end
            else
              free_spaces.select do |space|
                space.size >= smaller_volume(volumes, target_size)
              end
            end
          end
=end

          def candidate_spaces(volumes, free_spaces, target_size)
            volumes.each_with_object({}) do |volume, hash|
              spaces = free_spaces.select { |space| suitable_space?(space, volume, target_size) }
              if spaces.empty?
                raise NoDiskSpaceError, "No suitable free space for #{volume}"
              end
              hash[volume] = spaces
            end
          end

          def suitable_space?(space, volume, target_size)
            return false if volume.disk && volume.disk != space.disk_name
            return false if space.size < volume.min_valid_size(target_size)
            max_offset = volume.max_start_offset
            return false if max_offset && space.start_offset > max_offset
            true
          end

          def hash_product(hash)
            keys = hash.keys
            # Ensure same order
            arrays = keys.map { |key| hash[key] }
            product = arrays[0].product(*arrays[1..-1])
            product.map { |p| Hash[keys.zip(p)] }
          end

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
end
