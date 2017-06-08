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

      def initialize(devicegraph)
        @devicegraph = devicegraph
      end

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

      attr_reader :devicegraph

      def planned_for_disk(disk, description)
        result = []
        description["partitions"].each do |part_description|
          # TODO: fix Planned::Partition.initialize
          part = Y2Storage::Planned::Partition.new(nil, nil)
          part.disk = disk.name
          # part.bootable no está en el perfil (¿existe lógica?)
          part.filesystem_type = filesystem_for(part_description["filesystem"])
          part.partition_id = 131 # TODO: El que venga. Si nil, swap o linux
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
            # TODO: error si 1) no se especificó un dispositivo o 2) no existe
          end

          # Sizes: leave out reducing fixed sizes and 'auto'
          min_size, max_size = sizes_for(part_description, disk)
          part.min_size = min_size
          part.max_size = max_size
          result << part
        end

        result
      end

      SIZE_REGEXP = /([\d,.]+)?([a-zA-Z%]+)/
      def sizes_for(description, disk)
        normalized_size = description["size"].to_s.strip.downcase
        return [disk.min_grain, DiskSize.unlimited] if normalized_size == "max" || normalized_size.empty?

        _all, number, unit = SIZE_REGEXP.match(normalized_size).to_a
        size =
          if unit == "%"
            percent = number.to_f
            (disk.size * percent) / 100.0
          else
            DiskSize.parse(description["size"], legacy_units: true)
          end
        [size, size]
      end

      def filesystem_for(filesystem)
        Y2Storage::Filesystems::Type.find(filesystem)
      end

      def find_partition_to_reuse(devicegraph, part_description)
        if part_description["partition_nr"]
          devicegraph.partitions.find { |p| p.number == part_description["partition_nr"] }
        elsif part_description["label"]
          devicegraph.partitions.find { |p| p.filesystem_label == part_description["label"] }
        end
      end
    end
  end
end
