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

        drives_map.each_pair do |disk_name, drive_spec|
          disk = Disk.find_by_name(devicegraph, disk_name)
          case drive_spec.fetch("type", :CT_DISK)
          when :CT_DISK
            result.concat(planned_for_disk(disk, drive_spec))
          when :CT_LVM
            result << planned_for_vg(drive_spec)
          end
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
      # @param disk [Disk] Disk to place the partitions on
      # @param spec [Hash] Partitioning specification from AutoYaST
      # @return [Array<Planned::Partition>] List of planned partitions
      def planned_for_disk(disk, spec)
        result = []
        spec.fetch("partitions", []).each do |partition_spec|
          # TODO: fix Planned::Partition.initialize
          partition = Y2Storage::Planned::Partition.new(nil, nil)
          partition.disk = disk.name
          partition.lvm_volume_group_name = partition_spec["lvm_group"]
          # TODO: partition.bootable is not in the AutoYaST profile. Check if
          # there's some logic to set it in the old code.

          # TODO: set the correct id based on the filesystem type (move to Partition class?)
          partition.partition_id = 131
          add_common_device_attrs(partition, partition_spec)
          add_partition_reuse(partition, partition_spec) unless partition_spec.fetch("create", true)

          # Sizes: leave out reducing fixed sizes and 'auto'
          min_size, max_size = sizes_for(partition_spec["size"], disk.min_grain, disk.size)
          partition.min_size = min_size
          partition.max_size = max_size
          partition.weight = 1 if max_size == DiskSize.unlimited
          result << partition
        end

        result
      end

      # Returns a planned volume group according to an AutoYaST specification
      #
      # @param spec [Hash] Partitioning specification from AutoYaST
      # @return [Planned::LvmVg] Planned volume group
      def planned_for_vg(spec)
        vg = Y2Storage::Planned::LvmVg.new(volume_group_name: File.basename(spec["device"]))

        spec.fetch("partitions", []).each_with_object(vg.lvs) do |lv_spec, lvs|
          lv = Y2Storage::Planned::LvmLv.new(lv_spec["mount"], filesystem_for(lv_spec["filesystem"]))
          lv.logical_volume_name = lv_spec["lv_name"]
          add_common_device_attrs(lv, lv_spec)
          add_lv_reuse(lv, vg.volume_group_name, lv_spec) unless lv_spec.fetch("create", true)

          number, unit = size_to_components(lv_spec["size"])
          if unit == "%"
            lv.percent_size = number
          else
            lv.min_size, lv.max_size = sizes_for(lv_spec["size"], vg.extent_size, DiskSize.unlimited)
          end
          lvs << lv
        end

        add_vg_reuse(vg, spec)
        vg
      end

      # Set common devices attributes
      #
      # This method modifies the first argument setting crypt_key, crypt_fs,
      # mount, label, uuid and filesystem.
      #
      # @param device [Planned::Device] Planned device
      # @param spec   [Hash]            Fragment of an AutoYaST specification
      def add_common_device_attrs(device, spec)
        device.encryption_password = spec["crypt_key"] if spec["crypt_fs"]
        device.mount_point = spec["mount"]
        device.label = spec["label"]
        device.uuid = spec["uuid"]
        device.filesystem_type = filesystem_for(spec["filesystem"]) if spec["filesystem"]
      end

      # Set 'reusing' attributes for a partition
      #
      # This method modifies the first argument setting the values related to
      # reusing a partition (reuse and format).
      #
      # @param partition [Planned::Partition] Planned partition
      # @param spec      [Hash]               Fragment of an AutoYaST specification
      def add_partition_reuse(partition, spec)
        partition_to_reuse = find_partition_to_reuse(devicegraph, spec)
        return unless partition_to_reuse
        add_device_reuse(partition, partition_to_reuse.name, !!spec["format"])
        # TODO: possible errors here
        #   - missing information about what device to use
        #   - the specified device was not found
      end

      # Set 'reusing' attributes for a logical volume
      #
      # This method modifies the first argument setting the values related to
      # reusing a logical volume (reuse and format).
      #
      # @param lv      [Planned::LvmLv] Planned logical volume
      # @param vg_name [String]         Volume group name to search for the logical volume to reuse
      # @param spec    [Hash]           Fragment of an AutoYaST specification
      def add_lv_reuse(lv, vg_name, spec)
        lv_to_reuse = find_lv_to_reuse(devicegraph, vg_name, spec)
        return unless lv_to_reuse
        lv.logical_volume_name ||= lv_to_reuse.lv_name
        add_device_reuse(lv, lv_to_reuse.name, !!spec["format"])
      end

      def add_device_reuse(device, name, format)
        device.reuse = name
        device.reformat = format
      end

      # Set 'reusing' attributes for a volume group
      #
      # This method modifies the first argument setting the values related to
      # reusing a volume group (reuse and format).
      #
      # @param vg   [Planned::LvmVg] Planned volume group
      # @param spec [Hash]           Fragment of an AutoYaST specification
      def add_vg_reuse(vg, spec)
        vg.make_space_policy = spec.fetch("keep_unknown_lv", false) ? :keep : :remove

        return unless vg.make_space_policy == :keep || vg.lvs.any?(&:reuse?)
        vg_to_reuse = find_vg_to_reuse(devicegraph, vg)
        vg.reuse = vg_to_reuse.vg_name if vg_to_reuse
      end

      # Returns min and max sizes for a size specification
      #
      # @param size_spec [String]   Device size specification from AutoYaST
      # @param min       [DiskSize] Minimum disk size
      # @param max       [DiskSize] Maximum disk size
      # @return [[DiskSize,DiskSize]] min and max sizes for the given partition
      #
      # @see SIZE_REGEXP
      def sizes_for(size_spec, min, max)
        normalized_size = size_spec.to_s.strip.downcase

        return [min, DiskSize.unlimited] if normalized_size == "max" || normalized_size.empty?

        number, unit = size_to_components(size_spec)
        size =
          if unit == "%"
            percent = number.to_f
            (max * percent) / 100.0
          else
            DiskSize.parse(size_spec, legacy_units: true)
          end
        [size, size]
      end

      # Regular expression to detect which kind of size is being used in an
      # AutoYaST <size> element
      SIZE_REGEXP = /([\d,.]+)?([a-zA-Z%]+)/

      # Extracts number and unit from an AutoYaST size specification
      #
      # @example Using with percentages
      #   size_to_components("30%") # => [30.0, "%"]
      # @example Using with space units
      #   size_to_components("30GiB") # => [30.0, "GiB"]
      #
      # @return [[number,unit]] Number and unit
      def size_to_components(size_spec)
        normalized_size = size_spec.to_s.strip
        number, unit = SIZE_REGEXP.match(normalized_size).values_at(1, 2)
        [number.to_f, unit]
      end

      # @param type [String,Symbol] Filesystem type name
      def filesystem_for(type)
        Y2Storage::Filesystems::Type.find(type)
      end

      # @param devicegraph [Devicegraph] Devicegraph to search for the partition to reuse
      # @param spec        [Hash]        Partition specification from AutoYaST
      def find_partition_to_reuse(devicegraph, spec)
        if spec["partition_nr"]
          devicegraph.partitions.find { |i| i.number == spec["partition_nr"] }
        elsif spec["label"]
          devicegraph.partitions.find { |i| i.filesystem_label == spec["label"] }
        end
      end

      # @param devicegraph [Devicegraph] Devicegraph to search for the logical volume to reuse
      # @param vg_name     [String]      Volume group name to search for the logical volume to reuse
      # @param spec        [Hash]        Fragment of an AutoYaST specification
      def find_lv_to_reuse(devicegraph, vg_name, spec)
        vg = devicegraph.lvm_vgs.find { |v| v.vg_name == vg_name }
        return unless vg
        if spec["lv_name"]
          vg.lvm_lvs.find { |v| v.lv_name == spec["lv_name"] }
        elsif spec["label"]
          vg.lvm_lvs.find { |v| v.filesystem_label == spec["label"] }
        end
      end

      # @param devicegraph [Devicegraph] Devicegraph to search for the volume group to reuse
      # @param vg          [Planned::LvmVg] Planned volume group
      def find_vg_to_reuse(devicegraph, vg)
        return nil unless vg.volume_group_name
        devicegraph.lvm_vgs.find { |v| v.vg_name == vg.volume_group_name }
      end
    end
  end
end
