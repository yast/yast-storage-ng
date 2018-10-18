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
require "y2storage/proposal/autoinst_size_parser"
require "y2storage/proposal/autoinst_disk_device_planner"
require "y2storage/proposal/autoinst_vg_planner"
require "y2storage/proposal/autoinst_md_planner"
require "y2storage/planned"

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
      # @return [Planned::DevicesCollection] Collection of planned devices
      def planned_devices(drives_map)
        devices = drives_map.each_pair.each_with_object([]) do |(disk_name, drive), memo|
          planned_devs =
            case drive.type
            when :CT_DISK
              planned_for_disk_device(drive, disk_name)
            when :CT_LVM
              planned_for_vg(drive)
            when :CT_MD
              planned_for_md(drive)
            end
          memo.concat(planned_devs) if planned_devs
        end

        collection = Planned::DevicesCollection.new(devices)
        remove_shadowed_subvols(collection.mountable)
        collection
      end

    protected

      # @return [Devicegraph] Starting devicegraph
      attr_reader :devicegraph
      # @return [AutoinstIssues::List] List of AutoYaST issues to register them
      attr_reader :issues_list

      def planned_for_disk_device(drive, disk_name)
        planner = Y2Storage::Proposal::AutoinstDiskDevicePlanner.new(devicegraph, issues_list)
        drive.device = disk_name
        planner.planned_devices(drive)
      end

      # Returns a planned volume group according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the volume group
      # @return [Planned::LvmVg] Planned volume group
      def planned_for_vg(drive)
        planner = Y2Storage::Proposal::AutoinstVgPlanner.new(devicegraph, issues_list)
        planner.planned_devices(drive)
      end

      # Returns a MD array according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing
      #   the MD RAID
      # @return [Planned::Md] Planned MD RAID
      def planned_for_md(drive)
        planner = Y2Storage::Proposal::AutoinstMdPlanner.new(devicegraph, issues_list)
        planner.planned_devices(drive)
      end

      def remove_shadowed_subvols(planned_devices)
        planned_devices.each do |device|
          device.shadowed_subvolumes(planned_devices).each do |subvol|
            # TODO: this should be reported to the user when the shadowed
            # subvolumes was specified in the profile.
            log.info "Subvolume #{subvol} would be shadowed. Removing it."
            device.subvolumes.delete(subvol)
          end
        end
      end
    end
  end
end
