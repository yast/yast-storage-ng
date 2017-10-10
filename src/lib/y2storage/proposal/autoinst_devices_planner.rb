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
require "y2storage/disk_size"
require "y2storage/boot_requirements_checker"
require "y2storage/subvol_specification"
require "y2storage/proposal_settings"

module Y2Storage
  module Proposal
    # Class to generate a list of Planned::Device objects that must be allocated
    # during the AutoYaST proposal.
    #
    # The list of planned devices is generated from the information that was
    # previously obtained from the AutoYaST profile. This is completely different
    # to the guided proposal equivalent ({DevicesPlanner}), which generates the
    # planned devices based on the proposal settings and its own logic.
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
        @default_subvolumes_used = false

        drives_map.each_pair do |disk_name, drive_section|
          disk = BlkDevice.find_by_name(devicegraph, disk_name)
          case drive_section.type
          when :CT_DISK
            result.concat(planned_for_disk(disk, drive_section))
          when :CT_LVM
            result << planned_for_vg(drive_section)
          when :CT_MD
            result << planned_for_md(drive_section)
          end
        end

        checker = BootRequirementsChecker.new(devicegraph, planned_devices: result)
        result.concat(checker.needed_partitions)
        remove_shadowed_subvols(result)

        result
      end

    protected

      PARTITION_MIN_SIZE = DiskSize.B(1)

      # @return [Devicegraph] Starting devicegraph
      attr_reader :devicegraph

      # Returns an array of planned partitions for a given disk
      #
      # @param disk [Disk,Dasd] Disk to place the partitions on
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the layout for the disk
      # @return [Array<Planned::Partition>] List of planned partitions
      def planned_for_disk(disk, drive)
        result = []
        drive.partitions.each do |partition_section|
          # Sizes: leave out reducing fixed sizes and 'auto'
          min_size, max_size = sizes_for(partition_section, PARTITION_MIN_SIZE, disk.size)
          next if min_size.nil?

          # TODO: fix Planned::Partition.initialize
          partition = Y2Storage::Planned::Partition.new(nil, nil)

          partition.min_size = min_size
          partition.max_size = max_size
          partition.weight = 1 if max_size == DiskSize.unlimited

          # TODO: partition.bootable is not in the AutoYaST profile. Check if
          # there's some logic to set it in the old code.

          partition.disk = disk.name
          partition.partition_id = partition_section.id_for_partition
          partition.lvm_volume_group_name = partition_section.lvm_group
          partition.raid_name = partition_section.raid_name

          device_config(partition, partition_section, drive)
          add_partition_reuse(partition, partition_section) if partition_section.create == false

          result << partition
        end

        result
      end

      # Returns a planned volume group according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the volume group
      # @return [Planned::LvmVg] Planned volume group
      def planned_for_vg(drive)
        vg = Y2Storage::Planned::LvmVg.new(volume_group_name: File.basename(drive.device))

        drive.partitions.each_with_object(vg.lvs) do |lv_section, lvs|
          # TODO: fix Planned::LvmLv.initialize
          lv = Y2Storage::Planned::LvmLv.new(nil, nil)
          lv.logical_volume_name = lv_section.lv_name
          device_config(lv, lv_section, drive)
          add_lv_reuse(lv, vg.volume_group_name, lv_section) if lv_section.create == false

          number, unit = size_to_components(lv_section.size)
          if unit == "%"
            lv.percent_size = number
          else
            lv.min_size, lv.max_size = sizes_for(lv_section, vg.extent_size, DiskSize.unlimited)
            next if lv.min_size.nil?
          end
          lvs << lv
        end

        add_vg_reuse(vg, drive)
        vg
      end

      # Returns a MD array according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the MD RAID
      # @return [Planned::Md] Planned MD RAID
      def planned_for_md(drive)
        md = Planned::Md.new(name: drive.name_for_md)

        part_section = drive.partitions.first
        device_config(md, part_section, drive)
        md.lvm_volume_group_name = part_section.lvm_group
        add_device_reuse(md, md.name, !!part_section.format) if part_section.create == false

        raid_options = part_section.raid_options
        if raid_options
          md.chunk_size = chunk_size_from_string(raid_options.chunk_size) if raid_options.chunk_size
          md.md_level = MdLevel.find(raid_options.raid_type) if raid_options.raid_type
          md.md_parity = MdParity.find(raid_options.parity_algorithm) if raid_options.parity_algorithm
        end

        md
      end

      def chunk_size_from_string(string)
        string =~ /\D/ ? DiskSize.parse(string) : DiskSize.KB(string.to_i)
      end

      # Set all the common attributes that are shared by any device defined by
      # a <partition> section of AutoYaST (i.e. a LV, MD or partition).
      #
      # @param device  [Planned::Device] Planned device
      # @param partition_section [AutoinstProfile::PartitionSection] AutoYaST
      #   specification of the concrete device
      # @param drive_section [AutoinstProfile::DriveSection] AutoYaST drive
      #   section containing the partition one
      def device_config(device, partition_section, drive_section)
        add_common_device_attrs(device, partition_section)
        add_snapshots(device, drive_section)
        add_subvolumes_attrs(device, partition_section)
      end

      # Set common devices attributes
      #
      # This method modifies the first argument setting crypt_key, crypt_fs,
      # mount, label, uuid and filesystem.
      #
      # @param device  [Planned::Device] Planned device
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_common_device_attrs(device, section)
        device.encryption_password = section.crypt_key if section.crypt_fs
        device.mount_point = section.mount
        device.label = section.label
        device.uuid = section.uuid
        device.filesystem_type = section.type_for_filesystem
        device.mount_by = section.type_for_mountby
        device.mkfs_options = section.mkfs_options
        device.fstab_options = section.fstab_options
      end

      # Set device attributes related to snapshots
      #
      # This method modifies the first argument
      #
      # @param device  [Planned::Device] Planned device
      # @param drive_section [AutoinstProfile::DriveSection] AutoYaST specification
      def add_snapshots(device, drive_section)
        return unless device.respond_to?(:root?) && device.root?

        # Always try to enable snapshots if possible
        snapshots = true
        snapshots = false if drive_section.enable_snapshots == false

        device.snapshots = snapshots
      end

      # Set devices attributes related to Btrfs subvolumes
      #
      # This method modifies the first argument setting default_subvolume and
      # subvolumes.
      #
      # @param device  [Planned::Device] Planned device
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_subvolumes_attrs(device, section)
        return unless device.btrfs?

        subvol_specs = section.subvolumes
        mount = device.mount_point

        if subvol_specs.empty? && mount == "/"
          @default_subvolumes_used = true
          subvol_specs = proposal_settings.subvolumes
        end

        device.default_subvolume = proposal_settings.btrfs_default_subvolume || ""
        device.subvolumes = subvol_specs
      end

      # Set 'reusing' attributes for a partition
      #
      # This method modifies the first argument setting the values related to
      # reusing a partition (reuse and format).
      #
      # @param partition [Planned::Partition] Planned partition
      # @param section   [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_partition_reuse(partition, section)
        partition_to_reuse = find_partition_to_reuse(devicegraph, section)
        return unless partition_to_reuse
        add_device_reuse(partition, partition_to_reuse.name, !!section.format)
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
      # @param section   [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_lv_reuse(lv, vg_name, section)
        lv_to_reuse = find_lv_to_reuse(devicegraph, vg_name, section)
        return unless lv_to_reuse
        lv.logical_volume_name ||= lv_to_reuse.lv_name
        add_device_reuse(lv, lv_to_reuse.name, !!section.format)
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
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the volume group
      def add_vg_reuse(vg, drive)
        vg.make_space_policy = drive.keep_unknown_lv ? :keep : :remove

        return unless vg.make_space_policy == :keep || vg.lvs.any?(&:reuse?)
        vg_to_reuse = find_vg_to_reuse(devicegraph, vg)
        vg.reuse = vg_to_reuse.vg_name if vg_to_reuse
      end

      def sizes_for(section, min, max)
        size = section.size.to_s.strip.downcase
        sizes =
          if size == "auto"
            auto_sizes_for(section.mount)
          else
            extract_sizes_for(section.size, min, max)
          end

        if sizes.nil? || sizes.any?(&:nil?)
          log.warn "Could not determine size for #{section.mount} (size='#{section.size}')"
        end

        sizes
      end

      # Returns min and max sizes for a size specification
      #
      # @param size_spec [String]   Device size specification from AutoYaST
      # @param min       [DiskSize] Minimum disk size
      # @param max       [DiskSize] Maximum disk size
      # @return [[DiskSize,DiskSize]] min and max sizes for the given partition
      #
      # @see SIZE_REGEXP
      def extract_sizes_for(size_spec, min, max)
        normalized_size = size_spec.to_s.strip.downcase

        return [min, DiskSize.unlimited] if ["", "max"].include?(normalized_size)

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
      INTEGER_SIZE_REGEXP = /^(\d)+$/
      INTEGER_SIZE_REGEXP_WITH_UNIT = /([\d,.]+)?([a-zA-Z%]+)/

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
        return [normalized_size.to_f, "B"] if INTEGER_SIZE_REGEXP.match(normalized_size)
        number, unit = INTEGER_SIZE_REGEXP_WITH_UNIT.match(normalized_size).values_at(1, 2)
        [number.to_f, unit]
      end

      # @param devicegraph [Devicegraph] Devicegraph to search for the partition to reuse
      # @param part_spec [AutoinstProfile::PartitionSection] Partition specification
      #   from AutoYaST
      def find_partition_to_reuse(devicegraph, part_spec)
        if part_spec.partition_nr
          devicegraph.partitions.find { |i| i.number == part_spec.partition_nr }
        elsif part_spec.label
          devicegraph.partitions.find { |i| i.filesystem_label == part_spec.label }
        end
      end

      # @param devicegraph [Devicegraph] Devicegraph to search for the logical volume to reuse
      # @param vg_name     [String]      Volume group name to search for the logical volume to reuse
      # @param part_spec   [AutoinstProfile::PartitionSection] LV specification from AutoYaST
      def find_lv_to_reuse(devicegraph, vg_name, part_spec)
        vg = devicegraph.lvm_vgs.find { |v| v.vg_name == vg_name }
        return unless vg
        if part_spec.lv_name
          vg.lvm_lvs.find { |v| v.lv_name == part_spec.lv_name }
        elsif part_spec.label
          vg.lvm_lvs.find { |v| v.filesystem_label == part_spec.label }
        end
      end

      # @param devicegraph [Devicegraph] Devicegraph to search for the volume group to reuse
      # @param vg          [Planned::LvmVg] Planned volume group
      def find_vg_to_reuse(devicegraph, vg)
        return nil unless vg.volume_group_name
        devicegraph.lvm_vgs.find { |v| v.vg_name == vg.volume_group_name }
      end

      # Instance of {ProposalSettings} based on the current product.
      #
      # Used to ensure consistency between the guided proposal and the AutoYaST
      # one when default values are used.
      #
      # @return [ProposalSettings]
      def proposal_settings
        @proposal_settings ||= ProposalSettings.new_for_current_product
      end

      def remove_shadowed_subvols(planned_devices)
        planned_devices.each do |device|
          next unless device.respond_to?(:subvolumes)

          subvols_added =
            device.respond_to?(:mount_point) && device.mount_point == "/" && @default_subvolumes_used

          device.shadowed_subvolumes(planned_devices).each do |subvol|
            if subvols_added
              log.info "Default subvolume #{subvol} would be shadowed. Removing it."
            else
              # TODO: this should be reported to the user, but first we need to
              # decide how error reporting will be handled in AutoinstProposal
              log.warn "Subvolume #{subvol} from the profile would be shadowed. Removing it."
            end
            device.subvolumes.delete(subvol)
          end
        end
      end

      DEFAULT_SIZES = {
        "swap" => [DiskSize.MiB(512), DiskSize.GiB(2)].freeze
      }.freeze

      # @return [nil,Array<DiskSize>]
      def auto_sizes_for(mount_point)
        spec = volume_spec_for(mount_point)
        return DEFAULT_SIZES[mount_point] if spec.nil?

        default_min, default_max = DEFAULT_SIZES[mount_point] || []
        [spec.min_size || default_min, spec.max_size || default_max]
      end

      def volume_spec_for(mount_point)
        return nil if proposal_settings.volumes.empty?
        proposal_settings.volumes.find { |v| v.mount_point == mount_point }
      end
    end
  end
end
