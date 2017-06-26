#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require "y2storage/disk"

module Y2Storage
  module Proposal
    # Class to generate a list of Planned::Device objects that must be allocated
    # during the AutoYaST proposal.
    #
    # The list of planned devices is generated from the information that was
    # previously obtained from the AutoYaST profile. This is completely different
    # to the guided proposal equivalent ({PlannedDevicesGenerator}), which
    # generates the planned devices based on the proposal settings and its own
    # logic.
    class AutoinstDevicesPlanner
      include Yast::Logger

      # Constructor
      #
      # @param devicegraph [Devicegraph] Devicegraph to be used as starting point
      def initialize(devicegraph)
        @devicegraph = devicegraph
      end

      # Returns an array of planned devices according to the drives map
      #
      # @param drives_map [Proposal::AutoinstDrivesMap] Drives map from AutoYaST
      # @return [Array<Planned::Partition>] List of planned partitions
      def planned_devices(drives_map)
        result = []

        drives_map.each_pair do |disk_name, drive_section|
          disk = Disk.find_by_name(devicegraph, disk_name)
          result.concat(planned_for_disk(disk, drive_section))
        end

        checker = BootRequirementsChecker.new(devicegraph, planned_devices: result)
        result.concat(checker.needed_partitions)

        result
      end

    protected

      # @return [Devicegraph] Starting devicegraph
      attr_reader :devicegraph

      # Returns an array of planned partitions for a given disk
      #
      # @param disk  [Disk] Disk to place the partitions on
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the layout for the disk
      # @return [Array<Planned::Partition>] List of planned partitions
      def planned_for_disk(disk, drive)
        result = []
        drive.partitions.each do |partition_section|
          # TODO: fix Planned::Partition.initialize
          partition = Y2Storage::Planned::Partition.new(nil, nil)

          # TODO: partition.bootable is not in the AutoYaST profile. Check if
          # there's some logic to set it in the old code.

          partition.disk = disk.name
          partition.filesystem_type = partition_section.type_for_filesystem
          partition.partition_id = partition_section.id_for_partition
          if partition_section.crypt_fs
            partition.encryption_password = partition_section.crypt_key
          end
          partition.mount_point = partition_section.mount
          partition.label = partition_section.label
          partition.uuid = partition_section.uuid
          if partition_section.create == false
            partition_to_reuse = find_partition_to_reuse(devicegraph, partition_section)
            if partition_to_reuse
              partition.reuse = partition_to_reuse.name
              partition.reformat = !!partition_section.format
            end
            # TODO: possible errors here
            #   - missing information about what device to use
            #   - the specified device was not found
          end

          # Sizes: leave out reducing fixed sizes and 'auto'
          min_size, max_size = sizes_for(partition_section, disk)
          partition.min_size = min_size
          partition.max_size = max_size
          result << partition
        end

        result
      end

      # Regular expression to detect which kind of size is being used in an
      # AutoYaST <size> element
      SIZE_REGEXP = /([\d,.]+)?([a-zA-Z%]+)/

      # Returns min and max sizes for a partition specification
      #
      # @param part_spec [AutoinstProfile::PartitionSection] Partition
      #   specification from AutoYaST
      # @param [Disk] disk to which the planned partition will be assigned to
      # @return [[DiskSize,DiskSize]] min and max sizes for the given partition
      #
      # @see SIZE_REGEXP
      def sizes_for(part_spec, disk)
        normalized_size = part_spec.size.to_s.strip.downcase

        if normalized_size == "max" || normalized_size.empty?
          return [disk.min_grain, DiskSize.unlimited]
        end

        number, unit = SIZE_REGEXP.match(normalized_size).values_at(1, 2)
        size =
          if unit == "%"
            percent = number.to_f
            (disk.size * percent) / 100.0
          else
            DiskSize.parse(part_spec.size, legacy_units: true)
          end
        [size, size]
      end

      # @param devicegraph [Devicegraph] Devicegraph to search for the partitio to reuse
      # @param part_spec [AutoinstProfile::PartitionSection] Partition specification
      #   from AutoYaST
      def find_partition_to_reuse(devicegraph, part_spec)
        if part_spec.partition_nr
          devicegraph.partitions.find { |i| i.number == part_spec.partition_nr }
        elsif part_spec.label
          devicegraph.partitions.find { |i| i.filesystem_label == part_spec.label }
        end
      end
    end
  end
end
