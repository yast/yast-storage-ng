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
require "y2storage/proposal/autoinst_size_parser"
require "y2storage/volume_specification"

module Y2Storage
  module Proposal
    # Class to generate a list of Planned::Device objects that must be allocated
    # during the AutoYaST proposal.
    #
    # The list of planned devices is generated from the information that was
    # previously obtained from the AutoYaST profile. This is completely different
    # to the guided proposal equivalent ({DevicesPlanner}), which generates the
    # planned devices based on the proposal settings and its own logic.
    #
    # rubocop:disable ClassLength
    class AutoinstDevicesPlanner
      include Yast::Logger

      # Constructor
      #
      # @param devicegraph [Devicegraph] Devicegraph to be used as starting point
      # @param issues_list [AutoinstIssues::List] List of AutoYaST issues to register them
      def initialize(devicegraph, issues_list)
        @devicegraph = devicegraph
        @issues_list = issues_list
      end

      # Returns an array of planned devices according to the drives map
      #
      # @param drives_map [Proposal::AutoinstDrivesMap] Drives map from AutoYaST
      # @return [Array<Planned::Device>] List of planned devices
      def planned_devices(drives_map)
        result = []

        drives_map.each_pair do |disk_name, drive_section|
          case drive_section.type
          when :CT_DISK
            disk = BlkDevice.find_by_name(devicegraph, disk_name)
            planned_devs =
              if disk
                planned_for_disk(disk, drive_section)
              else
                planned_for_stray_devices(drive_section)
              end
            result.concat(planned_devs)
          when :CT_LVM
            result << planned_for_vg(drive_section)
          when :CT_MD
            result << planned_for_md(drive_section)
          end
        end

        remove_shadowed_subvols(result)

        result
      end

    protected

      # @return [Devicegraph] Starting devicegraph
      attr_reader :devicegraph
      # @return [AutoinstIssues::List] List of AutoYaST issues to register them
      attr_reader :issues_list

      # Returns an array of planned partitions for a given disk
      #
      # @param disk [Disk,Dasd] Disk to place the partitions on
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the layout for the disk
      # @return [Array<Planned::Partition>] List of planned partitions
      def planned_for_disk(disk, drive)
        result = []
        drive.partitions.each_with_index do |section|
          # TODO: fix Planned::Partition.initialize
          partition = Y2Storage::Planned::Partition.new(nil, nil)

          next unless assign_size_to_partition(disk, partition, section)

          # TODO: partition.bootable is not in the AutoYaST profile. Check if
          # there's some logic to set it in the old code.

          partition.disk = disk.name
          partition.partition_id = section.id_for_partition
          partition.lvm_volume_group_name = section.lvm_group
          partition.raid_name = section.raid_name
          partition.primary = section.partition_type == "primary" if section.partition_type

          device_config(partition, section, drive)
          add_partition_reuse(partition, section) if section.create == false

          result << partition
        end

        result
      end

      # Returns an array of planned Xen partitions according to a <drive>
      # section which groups virtual partitions with a similar name (e.g. a
      # "/dev/xvda" section describing "/dev/xvda1" and "/dev/xvda2").
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   a set of stray block devices (Xen virtual partitions)
      # @return [Array<Planned::StrayBlkDevice>] List of planned devices
      def planned_for_stray_devices(drive)
        result = []
        drive.partitions.each do |section|
          # Since this drive section was included in the drives map, we can be
          # sure that all partitions include a valid partition_nr
          # (see {AutoinstDrivesMap#stray_devices_group?}).
          name = drive.device + section.partition_nr.to_s
          stray = Y2Storage::Planned::StrayBlkDevice.new
          device_config(stray, section, drive)

          # Just for symmetry respect partitions, try to infer the filesystem
          # type if it's omitted in the profile for devices that are going to be
          # re-formatted but not mounted, so there is no reasonable way to infer
          # the appropiate filesystem type based on the mount path (bsc#1060637).
          if stray.filesystem_type.nil?
            device_to_use = devicegraph.stray_blk_devices.find { |d| d.name == name }
            stray.filesystem_type = device_to_use.filesystem_type if device_to_use
          end

          add_device_reuse(stray, name, section)

          result << stray
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

        pools, regular = drive.partitions.partition(&:pool)
        (pools + regular).each_with_object(vg.lvs) do |lv_section, lvs|
          lv = planned_for_lv(drive, vg, lv_section)
          next if lv.nil? || lv.lv_type == LvType::THIN
          lvs << lv
        end

        vg.thin_pool_lvs.each { |v| add_thin_pool_lv_reuse(v, drive) }
        add_vg_reuse(vg, drive)
        vg
      end

      # Returns a planned logical volume according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the volume group
      # @param vg [Planned::LvmVg] Planned volume group where the logical volume will
      #   be included
      # @param section [AutoinstProfile::PartitionSection] partition section describing
      #   the logical volume
      # @return [Planned::LvmLv,nil] Planned logical volume; nil if it could not be
      #   planned
      def planned_for_lv(drive, vg, section)
        # TODO: fix Planned::LvmLv.initialize
        lv = Y2Storage::Planned::LvmLv.new(nil, nil)
        lv.logical_volume_name = section.lv_name
        lv.lv_type = lv_type_for(section)
        add_stripes(lv, section)
        device_config(lv, section, drive)
        if section.used_pool
          return nil unless add_to_thin_pool(lv, vg, section)
        end
        add_lv_reuse(lv, vg.volume_group_name, section) if section.create == false
        assign_size_to_lv(vg, lv, section) ? lv : nil
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
        add_md_reuse(md, part_section) if part_section.create == false

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
        device.filesystem_type = filesystem_for(section)
        device.mount_by = section.type_for_mountby
        device.mkfs_options = section.mkfs_options
        device.fstab_options = section.fstab_options
        device.read_only = read_only?(section.mount)
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

        defaults = subvolume_attrs_for(device.mount_point)

        device.default_subvolume = section.subvolumes_prefix || defaults[:subvolumes_prefix]

        device.subvolumes =
          if section.create_subvolumes
            section.subvolumes || defaults[:subvolumes] || []
          else
            []
          end
      end

      # Return the default subvolume attributes for a given mount point
      #
      # @param mount [String] Mount point
      # @return [Hash]
      def subvolume_attrs_for(mount)
        return {} if mount.nil?
        spec = VolumeSpecification.for(mount)
        return {} if spec.nil?
        { subvolumes_prefix: spec.btrfs_default_subvolume, subvolumes: spec.subvolumes }
      end

      # Set 'reusing' attributes for a partition
      #
      # This method modifies the first argument setting the values related to
      # reusing a partition (reuse and format).
      #
      # @param partition [Planned::Partition] Planned partition
      # @param section   [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_partition_reuse(partition, section)
        partition_to_reuse = find_partition_to_reuse(section)
        return unless partition_to_reuse
        partition.filesystem_type ||= partition_to_reuse.filesystem_type
        add_device_reuse(partition, partition_to_reuse.name, section)
      end

      # Set 'reusing' attributes for a logical volume
      #
      # This method modifies the first argument setting the values related to
      # reusing a logical volume (reuse and format).
      #
      # @param lv      [Planned::LvmLv] Planned logical volume
      # @param vg_name [String]         Volume group name to search for the logical volume to reuse
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_lv_reuse(lv, vg_name, section)
        lv_to_reuse = find_lv_to_reuse(vg_name, section)
        return unless lv_to_reuse
        lv.logical_volume_name ||= lv_to_reuse.lv_name
        lv.filesystem_type ||= lv_to_reuse.filesystem_type
        add_device_reuse(lv, lv_to_reuse.name, section)
        add_device_reuse(lv.thin_pool, vg_name, section) if lv.thin_pool
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

        return unless vg.make_space_policy == :keep || vg.all_lvs.any?(&:reuse?)
        vg_to_reuse = find_vg_to_reuse(vg, drive)
        vg.reuse_name = vg_to_reuse.vg_name if vg_to_reuse
      end

      # Set 'reusing' attributes for a thin pool logical volume
      #
      # This method modifies the argument setting the values related to reusing
      # a thin logical volume (reuse_name). A thin pool will be planned to be
      # reused if any of its logical volumes will be reused.
      #
      # @param lv   [Planned::LvmLv] Thin logical volume
      def add_thin_pool_lv_reuse(lv, _drive)
        return unless lv.thin_lvs.any?(&:reuse?)
        lv_to_reuse = devicegraph.lvm_lvs.find { |v| lv.logical_volume_name == v.lv_name }
        lv.reuse_name = lv_to_reuse.name
      end

      # Set 'reusing' attributes for a MD RAID
      #
      # @param md      [Planned::Md] Planned MD RAID
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_md_reuse(md, section)
        # TODO: fix when not using named raids
        md_to_reuse = devicegraph.md_raids.find { |m| m.name == md.name }
        if md_to_reuse.nil?
          issues_list.add(:missing_reusable_device, section)
          return
        end
        add_device_reuse(md, md_to_reuse.name, section)
      end

      # @param device  [Planned::Partition,Planned::LvmLV] Planned device
      # @param name    [String] Name of the device to reuse
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      def add_device_reuse(device, name, section)
        device.reuse_name = name
        device.reformat = !!section.format
        device.resize = !!section.resize if device.respond_to?(:resize=)
      end

      # @param part_section [AutoinstProfile::PartitionSection] Partition specification
      #   from AutoYaST
      def find_partition_to_reuse(part_section)
        device =
          if part_section.partition_nr
            devicegraph.partitions.find { |i| i.number == part_section.partition_nr }
          elsif part_section.label
            devicegraph.partitions.find { |i| i.filesystem_label == part_section.label }
          else
            issues_list.add(:missing_reuse_info, part_section)
            nil
          end

        issues_list.add(:missing_reusable_device, part_section) unless device
        device
      end

      # @param vg_name     [String]      Volume group name to search for the logical volume to reuse
      # @param part_section   [AutoinstProfile::PartitionSection] LV specification from AutoYaST
      def find_lv_to_reuse(vg_name, part_section)
        parent = find_lv_parent(vg_name, part_section)
        return if parent.nil?

        device =
          if part_section.lv_name
            parent.lvm_lvs.find { |v| v.lv_name == part_section.lv_name }
          elsif part_section.label
            parent.lvm_lvs.find { |v| v.filesystem_label == part_section.label }
          else
            issues_list.add(:missing_reuse_info, part_section)
            :missing_info
          end

        issues_list.add(:missing_reusable_device, part_section) unless device
        :missing_info == device ? nil : device
      end

      # @param vg_name     [String]      Volume group name to search for the logical volume
      # @param part_section   [AutoinstProfile::PartitionSection] LV specification from AutoYaST
      def find_lv_parent(vg_name, part_section)
        vg = devicegraph.lvm_vgs.find { |v| v.vg_name == vg_name }
        if vg.nil?
          issues_list.add(:missing_reusable_device, part_section)
          return
        end

        part_section.used_pool ? find_thin_pool_lv(vg, part_section) : vg
      end

      # @param vg          [Planned::LvmVg] Planned volume group
      # @param drive       [AutoinstProfile::DriveSection] drive section describing
      def find_vg_to_reuse(vg, drive)
        return nil unless vg.volume_group_name
        device = devicegraph.lvm_vgs.find { |v| v.vg_name == vg.volume_group_name }
        issues_list.add(:missing_reusable_device, drive) unless device
        device
      end

      # @param vg [LvmVg]   Logical volume group
      # @param part_section [AutoinstProfile::PartitionSection] LV specification from AutoYaST
      def find_thin_pool_lv(vg, part_section)
        lv = vg.lvm_lvs.find { |v| v.lv_name == part_section.used_pool }
        return lv if lv
        issues_list.add(:thin_pool_not_found, part_section)
        nil
      end

      # @return [DiskSize] Minimal partition size
      PARTITION_MIN_SIZE = DiskSize.B(1).freeze

      # Assign disk size according to AutoYaSt section
      #
      # @param disk        [Disk,Dasd]          Disk to put the partitions on
      # @param partition   [Planned::Partition] Partition to assign the size to
      # @param part_section   [AutoinstProfile::PartitionSection] Partition specification from AutoYaST
      def assign_size_to_partition(disk, partition, part_section)
        size_info = parse_size(part_section, PARTITION_MIN_SIZE, disk.size)

        if size_info.nil?
          issues_list.add(:invalid_value, part_section, :size)
          return false
        end

        partition.min_size = size_info.min
        partition.max_size = size_info.max
        partition.weight = 1 if size_info.unlimited?
        true
      end

      # Assign LV size according to AutoYaST section
      #
      # @param vg         [Planned::LvmVg] Volume group
      # @param lv         [Planned::LvmLv] Logical volume
      # @param lv_section [AutoinstProfile::PartitionSection] AutoYaST section
      # @return [Boolean] true if the size was parsed and asssigned; false it was not valid
      def assign_size_to_lv(vg, lv, lv_section)
        size_info = parse_size(lv_section, vg.extent_size, DiskSize.unlimited)

        if size_info.nil?
          issues_list.add(:invalid_value, lv_section, :size)
          return false
        end

        if size_info.percentage
          lv.percent_size = size_info.percentage
        else
          lv.min_size = size_info.min
          lv.max_size = size_info.max
        end
        lv.weight = 1 if size_info.unlimited?

        true
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

          device.shadowed_subvolumes(planned_devices).each do |subvol|
            # TODO: this should be reported to the user when the shadowed
            # subvolumes was specified in the profile.
            log.info "Subvolume #{subvol} would be shadowed. Removing it."
            device.subvolumes.delete(subvol)
          end
        end
      end

      # Parse the 'size' element
      #
      # @param section [AutoinstProfile::PartitionSection]
      # @param min     [DiskSize] Minimal size
      # @param max     [DiskSize] Maximal size
      # @see AutoinstSizeParser
      def parse_size(section, min, max)
        AutoinstSizeParser.new(proposal_settings).parse(section.size, section.mount, min, max)
      end

      # Return the filesystem type for a given section
      #
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      # @return [Filesystems::Type] Filesystem type
      def filesystem_for(section)
        return section.type_for_filesystem if section.type_for_filesystem
        return nil unless section.mount
        default_filesystem_for(section)
      end

      # Return the logical volume type for a given section
      #
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      # @return [LvType] Logical volume type
      def lv_type_for(section)
        if section.pool
          LvType::THIN_POOL
        elsif section.used_pool
          LvType::THIN
        else
          LvType::NORMAL
        end
      end

      # Add a logical volume to a thin pool
      #
      # @param lv [Planned::LvmLv] Planned logical volume
      # @param vg [Planned::LvmVg] Planned volume group
      # @param section [AutoinstProfile::PartitionSection] AutoYaST specification
      # @return [Boolean] True if it was successfully added; false otherwise.
      def add_to_thin_pool(lv, vg, section)
        thin_pool = vg.thin_pool_lvs.find { |v| v.logical_volume_name == section.used_pool }
        if thin_pool.nil?
          issues_list.add(:thin_pool_not_found, section)
          return false
        end
        thin_pool.add_thin_lv(lv)
      end

      # Return the default filesystem type for a given section
      #
      # @param section [AutoinstProfile::PartitionSection]
      # @return [Filesystems::Type] Filesystem type
      def default_filesystem_for(section)
        spec = VolumeSpecification.for(section.mount)
        return spec.fs_type if spec && spec.fs_type
        section.mount == "swap" ? Filesystems::Type::SWAP : Filesystems::Type::BTRFS
      end

      # Determine whether the filesystem for the given mount point should be read-only
      #
      # @param mount_point [String] Filesystem mount point
      # @return [Boolean] true if it should be read-only; false otherwise.
      def read_only?(mount_point)
        return false unless mount_point
        spec = VolumeSpecification.for(mount_point)
        !!spec && spec.btrfs_read_only?
      end

      # Sets stripes related attributes
      #
      # @param lv      [Planned::LvmLv] Planned logical volume
      # @param section [AutoinstProfile::PartitionSection] partition section describing
      #   the logical volume
      def add_stripes(lv, section)
        lv.stripe_size = DiskSize.KiB(section.stripe_size.to_i) if section.stripe_size
        lv.stripes = section.stripes
      end
    end
  end
end
