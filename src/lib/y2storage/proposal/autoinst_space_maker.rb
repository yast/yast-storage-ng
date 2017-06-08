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

      def initialize(disk_analyzer)
        @disk_analyzer = disk_analyzer
      end

      def provide_space(initial_devicegraph, drives_map)
        devicegraph = initial_devicegraph.dup

        drives_map.each_pair do |disk_name, drive_spec|
          disk = Disk.find_by_name(devicegraph, disk_name)
          delete_stuff(devicegraph, disk, drive_spec)
        end

        devicegraph
      end

    protected

      attr_reader :disk_analyzer

      # Delete unwanted partitions for the given disk
      #
      # @param disk        [Y2Storage::Disk] Disk
      # @param drive_spec [Hash] Drive drive_spec from AutoYaST
      # @option drive_spec [Boolean] "initialize" Initialize the device
      # @option drive_spec [String]  "use"        Partitions to remove ("all", "linux", nil)
      def delete_stuff(devicegraph, disk, drive_spec)
        if drive_spec["initialize"]
          disk.remove_descendants
          return
        end

        # TODO: resizing of partitions

        case drive_spec["use"]
        when "all"
          disk.partition_table.remove_descendants if disk.partition_table
        when "linux"
          delete_linux_partitions(devicegraph, disk)
        end
      end

      def delete_linux_partitions(devicegraph, disk)
        partition_killer = Proposal::PartitionKiller.new(devicegraph)
        parts = disk_analyzer.linux_partitions(disk)
        # TODO: when introducing supporting for LVM, should we protect here
        # the PVs of VGs that are going to be reused somehow?
        parts.map(&:name).each { |n| partition_killer.delete(n) }
      end
    end
  end
end
