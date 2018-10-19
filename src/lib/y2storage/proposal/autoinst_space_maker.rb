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
require "y2storage/planned/lvm_vg"
require "y2storage/planned/lvm_lv"

module Y2Storage
  module Proposal
    # Class to provide free space during the AutoYaST proposal by deleting
    # partitions and partition tables according to the information in the
    # AutoYaST profile.
    class AutoinstSpaceMaker
      include Yast::Logger

      # @return [AutoinstIssues::List] List of detected problems
      attr_reader :issues_list

      # Constructor
      #
      # @param disk_analyzer [DiskAnalyzer] information about existing partitions
      def initialize(disk_analyzer, issues_list = nil)
        @disk_analyzer = disk_analyzer
        @issues_list = issues_list || AutoinstIssues::List.new
      end

      # Performs all the delete operations specified in the AutoYaST profile
      #
      # @param original_devicegraph [Devicegraph] initial devicegraph
      # @param drives_map           [AutoinstDrivesMap] drives map
      # @param planned_devices      [Array<Planned::Partition>] set of partitions
      #   to make space for.
      def cleaned_devicegraph(original_devicegraph, drives_map, planned_devices)
        devicegraph = original_devicegraph.dup

        reused_partitions = reused_partitions_by_disk(devicegraph, planned_devices)
        sid_map = partitions_sid_map(devicegraph)

        drives_map.each_pair do |disk_name, drive_spec|
          disk = BlkDevice.find_by_name(devicegraph, disk_name)
          next unless disk
          delete_stuff(devicegraph, disk, drive_spec, reused_partitions[disk.name])
        end

        adjust_reuse_values(devicegraph, planned_devices, sid_map)
        devicegraph
      end

    protected

      attr_reader :disk_analyzer

      # Deletes unwanted partitions for the given disk
      #
      # @param devicegraph  [Devicegraph]
      # @param disk         [Disk]
      # @param drive_spec   [AutoinstProfile::DriveSection]
      # @param reused_parts [Array<String>] Reused partitions names
      def delete_stuff(devicegraph, disk, drive_spec, reused_parts)
        reused_parts ||= []
        if drive_spec.initialize_attr && reused_parts.empty?
          disk.remove_descendants
          return
        end

        # TODO: resizing of partitions

        delete_by_use(devicegraph, disk, drive_spec, reused_parts)
      end

      # Deletes unwanted partition according to the "use" element
      #
      # @param devicegraph  [Devicegraph]
      # @param disk         [Disk]
      # @param drive_spec   [AutoinstProfile::DriveSection]
      # @param reused_parts [Array<String>] Reused partitions names
      def delete_by_use(devicegraph, disk, drive_spec, reused_parts)
        return if drive_spec.use == "free" || !partition_table?(disk)
        case drive_spec.use
        when "all"
          delete_partitions(devicegraph, disk.partitions, reused_parts)
        when "linux"
          delete_linux_partitions(devicegraph, disk, reused_parts)
        when Array
          delete_partitions_by_number(devicegraph, disk, drive_spec.use, reused_parts)
        else
          register_invalid_use_value(drive_spec)
        end
      end

      # Search a partition by its sid
      #
      # @param devicegraph  [Devicegraph] Working devicegraph
      def partition_by_sid(devicegraph, sid)
        devicegraph.partitions.find { |p| p.sid == sid }
      end

      # Deletes Linux partitions from a disk in the given devicegraph
      #
      # @param devicegraph  [Devicegraph] Working devicegraph
      # @param disk         [Disk]        Disk to remove partitions from
      # @param reused_parts [Array<String>] Reused partitions names
      def delete_linux_partitions(devicegraph, disk, reused_parts)
        parts = disk_analyzer.linux_partitions(disk)
        delete_partitions(devicegraph, parts, reused_parts)
      end

      # Deletes Linux partitions which number is included in a list
      #
      # @param devicegraph [Devicegraph]    Working devicegraph
      # @param disk        [Disk]           Disk to remove partitions from
      # @param partition_nrs [Array<Integer>] List of partition numbers
      def delete_partitions_by_number(devicegraph, disk, partition_nrs, reused_partitions)
        parts = disk.partitions.select { |n| partition_nrs.include?(n.number) }
        delete_partitions(devicegraph, parts, reused_partitions)
      end

      # @param devicegraph     [Devicegraph]               devicegraph
      # @param parts           [Array<Planned::Partition>] parts to delete
      # @param reused_parts    [Array<String>]             reused partitions names
      def delete_partitions(devicegraph, parts, reused_parts)
        partition_killer = Proposal::PartitionKiller.new(devicegraph)
        parts_to_delete = parts.reject { |p| reused_parts.include?(p.name) }
        parts_to_delete.map(&:sid).each do |sid|
          partition = partition_by_sid(devicegraph, sid)
          next unless partition
          partition_killer.delete_by_sid(partition.sid)
        end
      end

      # Register an invalid/missing value for 'use'
      #
      # @param drive_spec  [AutoinstProfile::DriveSection]
      def register_invalid_use_value(drive_spec)
        if drive_spec.use
          issues_list.add(:invalid_value, drive_spec, :use)
        else
          issues_list.add(:missing_value, drive_spec, :use)
        end
      end

      # Return a map of reused partitions
      #
      # Calculates which partitions are meant to be reused and, as a consequence, should not
      # be deleted.
      #
      # @param devicegraph     [Devicegraph]               devicegraph
      # @param planned_devices [Array<Planned::Partition>] set of partitions
      # @return [Hash<String,Array<String>>] disk name to list of reused partitions map
      def reused_partitions_by_disk(devicegraph, planned_devices)
        find_reused_partitions(devicegraph, planned_devices).each_with_object({}) do |part, map|
          disk_name = part.partitionable.name
          map[disk_name] ||= []
          map[disk_name] << part.name
        end
      end

      # Determine which partitions will be reused
      #
      # @param devicegraph     [Devicegraph]               devicegraph
      # @param planned_devices [Array<Planned::Partition>] set of partitions
      # @return [Hash<String,Array<String>>] disk name to list of reused partitions map
      def find_reused_partitions(devicegraph, planned_devices)
        reused_devices = planned_devices.select(&:reuse_name).each_with_object([]) do |device, all|
          case device
          when Y2Storage::Planned::Partition
            all << devicegraph.partitions.find { |p| device.reuse_name == p.name }
          when Y2Storage::Planned::LvmVg
            vg = devicegraph.lvm_vgs.find { |v| File.join("/dev", device.reuse_name) == v.name }
            all.concat(vg.lvm_pvs)
          when Y2Storage::Planned::Md
            all << devicegraph.md_raids.find { |r| device.reuse_name == r.name }
          end
        end

        ancestors = reused_devices.map(&:ancestors).flatten
        (reused_devices + ancestors).select { |p| p.is_a?(Y2Storage::Partition) }
      end

      # Build a device name to sid map
      #
      # @param devicegraph [Devicegraph] devicegraph
      # @return [Hash<String,Integer>] Map with device names as keys and sid as values.
      #
      # @see adjust_reuse_values
      def partitions_sid_map(devicegraph)
        devicegraph.partitions.each_with_object({}) { |p, m| m[p.name] = p.sid }
      end

      # Adjust reuse values
      #
      # When using logical partitions (ms-dos), removing a partition might cause the rest of
      # logical partitions numbers to shift. In such a situation, 'reuse_name' properties of planned
      # devices will break (they might point to a non-existent device).
      #
      # This method takes care of setting the correct value for every 'reuse_name' property (thus
      # planned_devices are modified).
      #
      # @param devicegraph     [Devicegraph]               devicegraph
      # @param planned_devices [Array<Planned::Partition>] set of partitions to make space for
      # @param sid_map         [Hash<String,Integer>]      device name to sid map
      #
      # @see sid_map
      # rubocop:disable Style/MultilineBlockChain
      def adjust_reuse_values(devicegraph, planned_devices, sid_map)
        planned_devices.select do |d|
          d.is_a?(Y2Storage::Planned::Partition) && d.reuse_name
        end.each do |device|
          sid = sid_map[device.reuse_name]
          partition = partition_by_sid(devicegraph, sid)
          device.reuse_name = partition.name
        end
      end
      # rubocop:enable all

      # Determines whether a device has a partition table
      #
      # @param device [Device] Device
      # @return [Boolean] true if the device has a partition table; false otherwise
      def partition_table?(device)
        device.respond_to?(:partition_table) && !!device.partition_table
      end
    end
  end
end
