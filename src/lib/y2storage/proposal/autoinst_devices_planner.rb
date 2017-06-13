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
      # @raise [Error] if not partitions were specified
      #
      # @param drives_map [Proposal::AutoinstDrivesMap] Drives map from AutoYaST
      # @return [Array<Planned::Partition>] List of planned partitions
      def planned_devices(drives_map)
        result = []

        drives_map.each_pair do |disk_name, drive_spec|
          disk = Disk.find_by_name(devicegraph, disk_name)
          result.concat(planned_for_disk(disk, drive_spec))
        end

        if result.empty?
          raise Error, "No partitions specified"
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
      # @param disk         [Disk] Disk to place the partitions on
      # @param partitioning [Hash] Partitioning specification from AutoYaST
      # @return [Array<Planned::Partition>] List of planned partitions
      def planned_for_disk(disk, spec)
        result = []
        spec.fetch("partitions", []).each do |part_description|
          # TODO: fix Planned::Partition.initialize
          part = Y2Storage::Planned::Partition.new(nil, nil)
          part.disk = disk.name
          # part.bootable no está en el perfil (¿existe lógica?)
          part.filesystem_type = filesystem_for(part_description["filesystem"])
          # TODO: set the correct id based on the filesystem type (move to Partition class?)
          part.partition_id = 131
          if part_description["crypt_fs"]
            part.encryption_password = part_description["crypt_key"]
          end
          part.mount_point = part_description["mount"]
          part.label = part_description["label"]
          part.uuid = part_description["uuid"]
          if part_description["create"] == false
            partition_to_reuse = find_partition_to_reuse(devicegraph, part_description)
            if partition_to_reuse
              part.reuse = partition_to_reuse.name
              part.reformat = !!part_description["format"]
            end
            # TODO: possible errors here
            #   - missing information about what device to use
            #   - the specified device was not found
          end

          # Sizes: leave out reducing fixed sizes and 'auto'
          min_size, max_size = sizes_for(part_description, disk)
          part.min_size = min_size
          part.max_size = max_size
          result << part
        end

        result
      end

      # Regular expression to detect which kind of size is being used in an
      # AutoYaST <size> element
      SIZE_REGEXP = /([\d,.]+)?([a-zA-Z%]+)/

      # Returns min and max sizes for a partition specification
      #
      # @param description [Hash] Partition specification from AutoYaST
      # @return [[DiskSize,DiskSize]] min are max sizes for the given partition
      #
      # @see SIZE_REGEXP
      def sizes_for(part_spec, disk)
        normalized_size = part_spec["size"].to_s.strip.downcase

        if normalized_size == "max" || normalized_size.empty?
          return [disk.min_grain, DiskSize.unlimited]
        end

        _all, number, unit = SIZE_REGEXP.match(normalized_size).to_a
        size =
          if unit == "%"
            percent = number.to_f
            (disk.size * percent) / 100.0
          else
            DiskSize.parse(part_spec["size"], legacy_units: true)
          end
        [size, size]
      end

      # @param type [String,Symbol] Filesystem type name
      def filesystem_for(type)
        Y2Storage::Filesystems::Type.find(type)
      end

      # @param devicegraph [Devicegraph] Devicegraph to search for the partition to reuse
      # @param part_spec   [Hash]        Partition specification from AutoYaST
      def find_partition_to_reuse(devicegraph, part_spec)
        if part_spec["partition_nr"]
          devicegraph.partitions.find { |i| i.number == part_spec["partition_nr"] }
        elsif part_spec["label"]
          devicegraph.partitions.find { |i| i.filesystem_label == part_spec["label"] }
        end
      end
    end
  end
end
