# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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

require "y2storage/proposal/autoinst_drive_planner"
require "y2storage/planned/bcache"

Yast.import "Arch"

module Y2Storage
  module Proposal
    # This class converts an AutoYaST specification into a Planned::Bcache in order
    # to set up Bcache.
    class AutoinstBcachePlanner < AutoinstDrivePlanner
      # Returns a planned Bcache device.
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the Bcache set up
      # @return [Array<Planned::Bcache>] Planned Bcache device
      def planned_devices(drive)
        issues_list.add(:unsupported_drive_section, drive) unless Yast::Arch.x86_64
        bcaches =
          if drive.unwanted_partitions?
            non_partitioned_bcache(drive)
          else
            partition_bcache(drive)
          end
        Array(bcaches)
      end

    private

      # Returns a non partitioned Bcache device
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the Bcache set up
      # @return [Planned::Bcache] Planned Bcache device
      def non_partitioned_bcache(drive)
        bcache = Y2Storage::Planned::Bcache.new(name: drive.device)
        part_section = drive.partitions.first
        device_config(bcache, part_section, drive)
        add_bcache_reuse(bcache, part_section) if part_section.create == false
        add_bcache_options(bcache, drive.bcache_options)
        bcache
      end

      # Returns a partitioned Bcache device
      #
      # @param drive [AutoinstProfile::DriveSection] drive section describing the Bcache set up
      # @return [Planned::Bcache] Planned Bcache device
      def partition_bcache(drive)
        bcache = Y2Storage::Planned::Bcache.new(name: drive.device)
        if drive.disklabel
          bcache.ptable_type = Y2Storage::PartitionTables::Type.find(drive.disklabel)
        end
        bcache.partitions = drive.partitions.map do |part_section|
          plan_partition(bcache, drive, part_section)
        end
        add_bcache_reuse(bcache, drive) if bcache.partitions.any?(&:reuse?)
        add_bcache_options(bcache, drive.bcache_options)
        bcache
      end

      # Adds Bcache options
      #
      # @param bcache         [Planned::Bcache] Planned Bcache device
      # @param bcache_options [AutoinstProfile::BcacheOptionsSection,nil] User defined Bcache
      #   options
      def add_bcache_options(bcache, bcache_options)
        bcache.cache_mode = cache_mode_from(bcache_options)
      end

      # Sets 'reusing' attributes for a Bcache
      #
      # @param bcache  [Planned::Bcache] Planned Bcache
      # @param section [AutoinstProfile::PartitionSection,AutoinstProfile::Drive] AutoYaST
      #   specification
      def add_bcache_reuse(bcache, section)
        bcache_to_reuse = find_bcache_to_reuse(bcache)
        if bcache_to_reuse.nil?
          issues_list.add(:missing_reusable_device, section)
          return
        end
        bcache.reuse_name = bcache_to_reuse.name
      end

      # Bcache to be reused by the given planned Bcache
      #
      # @param bcache [Planned::Bcache] Planned Bcache
      def find_bcache_to_reuse(bcache)
        dev_by_name = devicegraph.find_by_any_name(bcache.name, alternative_names: true)

        return dev_by_name if dev_by_name && dev_by_name.is?(:bcache)
        nil
      end

      # Given a user specified RAID type, it returns the RAID level
      #
      # @note If the raid_type is not specified or is invalid, falls back to RAID1.
      #
      # @param bcache_options [AutoinstProfile::BcacheOptionsSection,nil] User defined Bcache
      #   options
      # @return [Y2Storage::CacheMode,nil] Bcache cache mode; nil if no cache mode was specified
      def cache_mode_from(bcache_options)
        return nil if bcache_options.nil? || bcache_options.cache_mode.nil?
        Y2Storage::CacheMode.find(bcache_options.cache_mode)
      rescue NameError
        issues_list.add(:invalid_value, bcache_options, :cache_mode, :skip)
        nil
      end
    end
  end
end
