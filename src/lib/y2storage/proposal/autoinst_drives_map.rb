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

require "y2storage/proposal/skip_list"

module Y2Storage
  module Proposal
    # Utility class to map disk names to the corresponding AutoYaST <drive>
    # specification that will be applied to that disk.
    #
    # More information can be found in the 'Partitioning' section of the AutoYaST documentation:
    # https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#CreateProfile.Partitioning
    class AutoinstDrivesMap
      extend Forwardable

      # @!method each_pair
      #   Calls block once por each disk that contains the AutoYaST specification
      #   passing as arguments the disk name and the specification itself.
      #
      #   @example
      #     drives_map.each_pair do |disk_name, drive_spec|
      #       puts "Drive for #{disk_name}: #{drive_spec}"
      #     end
      #
      # @!method each
      #   @see #each_pair
      def_delegators :@drives, :each, :each_pair

      # Constructor
      #
      # @param devicegraph  [Devicegraph] Devicegraph where the disks are contained
      # @param partitioning [Array<Hash>] Partitioning layout from an AutoYaST profile
      def initialize(devicegraph, partitioning)
        @drives = {}

        disks = partitioning.select { |i| i.fetch("type", :CT_DISK) == :CT_DISK }
        add_disks(disks, devicegraph)
        vgs = partitioning.select { |i| i["type"] == :CT_LVM }
        add_vgs(vgs)
        @drives
      end

      # Returns the list of disk names
      #
      # @return [Array<String>] Disk names
      def disk_names
        @drives.keys
      end

      # Returns whether the map contains partitions
      #
      # @example Containing partitions
      #   devicegraph = Y2Storage::StorageManager.instance.y2storage_probed
      #   profile = [
      #     {
      #       "device" => "/dev/sda", "use" => "all", "partitions" => [
      #         { "mount" => "/" }
      #       ]
      #     }
      #   ]
      #   map = AutoinstMap.new(devicegraph, profile)
      #   map.partitions? # => true
      #
      # @example Not containing partitions
      #   devicegraph = Y2Storage::StorageManager.instance.y2storage_probed
      #   profile = [{ "device" => "/dev/sda", "use" => "all" }]
      #   map = AutoinstMap.new(devicegraph, profile)
      #   map.partitions? # => false
      def partitions?
        @drives.values.any? { |i| !i.fetch("partitions", []).empty? }
      end

    protected

      # Find the first usable disk for the given <drive> AutoYaST specification
      #
      # @param drive_spec  [Hash] AutoYaST drive specification
      # @param devicegraph [Devicegraph] Devicegraph
      # @return [String,nil] Usable disk name or nil if none is found
      def first_usable_disk(drive_spec, devicegraph)
        skip_list = SkipList.from_profile(drive_spec.fetch("skip_list", []))

        devicegraph.disk_devices.each do |disk|
          next if disk_names.include?(disk.name)
          next if skip_list.matches?(disk)

          return disk.name
        end
        nil
      end

      # Adds disks to the devices map
      #
      # If some disk does not specify a "device" property, an usable disk will
      # be chosen from the given devicegraph.
      #
      # @param disks [Array<Hash>] List of disk specifications from AutoYaST
      # @param devicegraph [Devicegraph] Devicegraph to search for disks for "flexible" devices
      def add_disks(disks, devicegraph)
        fixed_drives, flexible_drives = disks.partition { |i| i["device"] && !i["device"].empty? }
        fixed_drives.each do |drive|
          @drives[drive["device"]] = drive
        end

        flexible_drives.each do |drive|
          disk_name = first_usable_disk(drive, devicegraph)
          @drives[disk_name] = drive
        end
      end

      # Adds volume groups to the devices map
      #
      # All volume groups should have a "device" property.
      #
      # @param vgs [Array<Hash>] List of volume group specifications from AutoYaST
      def add_vgs(vgs)
        vgs.each { |v| @drives[v["device"]] = v }
      end
    end
  end
end
