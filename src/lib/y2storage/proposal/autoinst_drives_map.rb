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

      # CT_MD is not supported yet
      SUPPORTED_TYPES = [:CT_DISK, :CT_LVM].freeze

      # Constructor
      #
      # @param devicegraph  [Devicegraph] Devicegraph where the disks are contained
      # @param partitioning [Array<Hash>] Partitioning layout from an AutoYaST profile
      def initialize(devicegraph, partitioning)
        # By now, consider only regular disks
        disks = partitioning.select { |i| SUPPORTED_TYPES.include?(i.fetch("type", :CT_DISK)) }

        # First, assign fixed drives
        fixed_drives, flexible_drives = disks.partition { |i| i["device"] && !i["device"].empty? }
        @drives = fixed_drives.each_with_object({}) do |disk, memo|
          memo[disk["device"]] = disk
        end

        flexible_drives.each do |drive|
          disk_name = first_usable_disk(drive, devicegraph)
          # TODO: what happens if there is no suitable disk?
          @drives[disk_name] = drive
        end
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
      # @return [Disk,nil] Usable disk or nil if none is found
      def first_usable_disk(drive_spec, devicegraph)
        skip_list = SkipList.from_profile(drive_spec.fetch("skip_list", []))

        devicegraph.disk_devices.each do |disk|
          next if disk_names.include?(disk.name)
          next if skip_list.matches?(disk)

          return disk.name
        end
        nil
      end
    end
  end
end
