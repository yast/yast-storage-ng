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
    # Class to provide free space during the AutoYaST proposal by deleting
    # partitions and partition tables according to the information in the
    # AutoYaST profile.
    class AutoinstSpaceMaker
      include Yast::Logger

      # @return [AutoinstProblems::List] List of detected problems
      attr_reader :problems_list

      # Constructor
      #
      # @param disk_analyzer [DiskAnalyzer] information about existing partitions
      def initialize(disk_analyzer, problems_list = nil)
        @disk_analyzer = disk_analyzer
        @problems_list = problems_list || AutoinstProblems::List.new
      end

      # Performs all the delete operations specified in the AutoYaST profile
      #
      # @param original_devicegraph [Devicegraph] initial devicegraph
      # @param drives_map           [Array<Planned::Partition>] set of partitions
      #   to make space for.
      def cleaned_devicegraph(original_devicegraph, drives_map)
        devicegraph = original_devicegraph.dup

        drives_map.each_pair do |disk_name, drive_spec|
          disk = BlkDevice.find_by_name(devicegraph, disk_name)
          next unless disk
          delete_stuff(devicegraph, disk, drive_spec)
        end

        devicegraph
      end

    protected

      attr_reader :disk_analyzer

      # Deletes unwanted partitions for the given disk
      #
      # @param devicegraph [Devicegraph]
      # @param disk        [Disk]
      # @param drive_spec  [AutoinstProfile::DriveSection]
      def delete_stuff(devicegraph, disk, drive_spec)
        if drive_spec.initialize_attr
          disk.remove_descendants
          return
        end

        # TODO: resizing of partitions

        delete_by_use(devicegraph, disk, drive_spec.use)
      end

      # Deletes unwanted partition according to the "use" element
      #
      # @param devicegraph [Devicegraph]
      # @param disk        [Disk]
      # @param use         [String,Array<Integer>] Use value ("all", "linux", "free"
      #   or a list of partition numbers)
      def delete_by_use(devicegraph, disk, use)
        return if use == "free"
        case use
        when "all"
          disk.partition_table.remove_descendants if disk.partition_table
        when "linux"
          delete_linux_partitions(devicegraph, disk)
        when Array
          delete_partitions_by_number(devicegraph, disk, use)
        else
          register_invalid_use_value(disk, use)
        end
      end

      # Deletes Linux partitions from a disk in the given devicegraph
      #
      # @param devicegraph [Devicegraph] Working devicegraph
      # @param disk        [Disk]        Disk to remove partitions from
      def delete_linux_partitions(devicegraph, disk)
        partition_killer = Proposal::PartitionKiller.new(devicegraph)
        parts = disk_analyzer.linux_partitions(disk)
        # TODO: when introducing supporting for LVM, should we protect here
        # the PVs of VGs that are going to be reused somehow?
        parts.map(&:name).each { |n| partition_killer.delete(n) }
      end

      # Deletes Linux partitions which number is included in a list
      #
      # @param devicegraph [Devicegraph]    Working devicegraph
      # @param disk        [Disk]           Disk to remove partitions from
      # @param partition_nrs [Array<Integer>] List of partition numbers
      def delete_partitions_by_number(devicegraph, disk, partition_nrs)
        partition_killer = Proposal::PartitionKiller.new(devicegraph)
        parts = disk.partitions.select { |n| partition_nrs.include?(n.number) }
        parts.map(&:name).each { |n| partition_killer.delete(n) }
      end

      # Register an invalid/missing value for 'use'
      #
      # @param disk        [Disk]
      # @param use         [String,Array<Integer>] Use value ("all", "linux", "free"
      def register_invalid_use_value(disk, use)
        if use.nil?
          problems_list.add(:missing_value, disk.name, :use)
        else
          problems_list.add(:invalid_value, disk.name, :use, use)
        end
      end
    end
  end
end
