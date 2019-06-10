# encoding: utf-8

# Copyright (c) [2017-2019] SUSE LLC
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
require "y2storage/proposal/autoinst_bcache_planner"
require "y2storage/proposal/autoinst_nfs_planner"
require "y2storage/proposal/autoinst_btrfs_planner"
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

      # Returns a collection of planned devices according to the drives map
      #
      # @param drives_map [Proposal::AutoinstDrivesMap] Drives map from AutoYaST
      # @return [Planned::DevicesCollection]
      def planned_devices(drives_map)
        devices = drives_map.each_pair.each_with_object([]) do |(disk_name, drive), memo|
          planned_devs = planned_for_drive(drive, disk_name)
          memo.concat(planned_devs) if planned_devs
        end

        collection = Planned::DevicesCollection.new(devices)
        remove_shadowed_subvols(collection.mountable_devices)
        add_bcache_issues(collection)
        collection
      end

    protected

      # @return [Devicegraph] Starting devicegraph
      attr_reader :devicegraph
      # @return [AutoinstIssues::List] List of AutoYaST issues to register them
      attr_reader :issues_list

      # FIXME: Disabling rubocop. Not sure how to improve this method without making it less readable.
      # rubocop:disable Metrics/CyclomaticComplexity
      #
      # Returns a list of planned devices according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the device
      # @param disk_name [String]
      #
      # @return [Array<Planned::Device>, nil] nil if the device cannot be planned
      def planned_for_drive(drive, disk_name)
        case drive.type
        when :CT_DISK
          planned_for_disk_device(drive, disk_name)
        when :CT_LVM
          planned_for_vg(drive)
        when :CT_MD
          planned_for_md(drive)
        when :CT_BCACHE
          planned_for_bcache(drive)
        when :CT_NFS
          planned_for_nfs(drive)
        when :CT_BTRFS
          planned_for_btrfs(drive)
        end
      end
      # rubocop:enable all

      # Returns a list of planned partitions (or disks) according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the partitions
      # @param disk_name [String]
      #
      # @return [Array<Planned::Partition, Planned::StrayBlkDevice>]
      def planned_for_disk_device(drive, disk_name)
        planner = Y2Storage::Proposal::AutoinstDiskDevicePlanner.new(devicegraph, issues_list)
        drive.device = disk_name
        planner.planned_devices(drive)
      end

      # Returns a list with the planned volume group according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the volume group
      # @return [Array<Planned::LvmVg>]
      def planned_for_vg(drive)
        planner = Y2Storage::Proposal::AutoinstVgPlanner.new(devicegraph, issues_list)
        planner.planned_devices(drive)
      end

      # Returns a list of planned MDs according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the MD RAID
      # @return [Array<Planned::Md>]
      def planned_for_md(drive)
        planner = Y2Storage::Proposal::AutoinstMdPlanner.new(devicegraph, issues_list)
        planner.planned_devices(drive)
      end

      # Returns a list of planned bcache devices according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the bcache device
      # @return [Array<Planned::Bcache>]
      def planned_for_bcache(drive)
        planner = Y2Storage::Proposal::AutoinstBcachePlanner.new(devicegraph, issues_list)
        planner.planned_devices(drive)
      end

      # Returns a list of planned NFS filesystems according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the NFS share
      # @return [Array<Planned::Nfs>]
      def planned_for_nfs(drive)
        planner = Y2Storage::Proposal::AutoinstNfsPlanner.new(devicegraph, issues_list)
        planner.planned_devices(drive)
      end

      # Returns a list of planned Btrfs filesystems according to an AutoYaST specification
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the Btrfs
      # @return [Array<Planned::Btrfs>]
      def planned_for_btrfs(drive)
        planner = Y2Storage::Proposal::AutoinstBtrfsPlanner.new(devicegraph, issues_list)
        planner.planned_devices(drive)
      end

      # Removes shadowed subvolumes from each planned device that can be mounted
      #
      # @param planned_devices [Array<Planned::Device>]
      def remove_shadowed_subvols(planned_devices)
        planned_devices.each do |device|
          # Some planned devices could be mountable but not formattable (e.g., {Planned::Nfs}).
          # Those devices might shadow some subvolumes but they do not have any subvolume to
          # be shadowed.
          next unless device.respond_to?(:shadowed_subvolumes)

          device.shadowed_subvolumes(planned_devices).each do |subvol|
            # TODO: this should be reported to the user when the shadowed
            # subvolumes was specified in the profile.
            log.info "Subvolume #{subvol} would be shadowed. Removing it."
            device.subvolumes.delete(subvol)
          end
        end
      end

      # Adds a bcache issue if needed
      #
      # @param collection [Planned::DevicesCollection] Planned devices
      def add_bcache_issues(collection)
        collection.bcaches.each do |bcache|
          add_bcache_issues_for(bcache.name, collection, :caching)
          add_bcache_issues_for(bcache.name, collection, :backing)
        end
      end

      # Add an issue if more than one device is defined as a backing/caching bcache member
      # @param bcache_name [String]
      # @param collection [Planned::DevicesCollection] Planned devices
      # @param role [Symbol] bcache member role (:backing, :caching)
      def add_bcache_issues_for(bcache_name, collection, role)
        method = "bcache_#{role}_for?".to_sym
        devs = collection.to_a.select do |dev|
          dev.respond_to?(method) && dev.send(method, bcache_name)
        end
        issues_list.add(:multiple_bcache_members, role, bcache_name) if devs.size > 1
      end
    end
  end
end
