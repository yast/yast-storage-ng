#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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

require "yast"
require "y2storage/planned"

module Y2Storage
  module BootRequirementsStrategies
    # Auxiliary class that takes information from several sources (current
    # devicegraph, already planned devices and user input) and provides useful
    # information (regarding calculation of boot requirements) about the
    # expected final system.
    class Analyzer
      # Constructor
      #
      # @see [BootRequirementsChecker#devicegraph]
      # @see [BootRequirementsChecker#planned_devices]
      # @see [BootRequirementsChecker#boot_disk_name]
      def initialize(devicegraph, planned_devices, boot_disk_name)
        @devicegraph = devicegraph
        @planned_devices = planned_devices
        @boot_disk_name = boot_disk_name

        @root_planned_dev = planned_devices.detect do |dev|
          dev.respond_to?(:mount_point) && dev.mount_point == "/"
        end
        @root_filesystem = devicegraph.filesystems.detect { |fs| fs.mountpoint == "/" }
      end

      # Disk in which the system will look for the bootloader.
      #
      # This is relevant only in some strategies (mainly legacy boot).
      #
      # There is no way to query the system for such value, so this method
      # relies on #boot_disk_name. If that information is not available, the
      # (first) disk hosting the root filesystem is considered to be the boot
      # disk.
      #
      # If "/" is still not present in the devicegraph or the list of planned
      # devices, the first disk of the system is used as fallback.
      #
      # @return [Disk]
      def boot_disk
        return @boot_disk if @boot_disk

        if boot_disk_name
          @boot_disk = devicegraph.disks.detect { |d| d.name == boot_disk_name }
        end

        @boot_disk ||= boot_disk_from_planned_dev
        @boot_disk ||= boot_disk_from_devicegraph
        @boot_disk ||= devicegraph.disks.first

        @boot_disk
      end

      # Whether the root (/) filesystem is going to be in a LVM logical volume
      def root_in_lvm?
        if root_planned_dev
          root_planned_dev.is_a?(Planned::LvmLv)
        elsif root_filesystem
          root_filesystem.plain_blk_devices.any? { |dev| dev.is?(:lvm_lv) }
        else
          false
        end
      end

      # Whether the root (/) filesystem is going to be in an encrypted device
      def encrypted_root?
        if root_planned_dev
          root_planned_dev.respond_to?(:encrypt?) && root_planned_dev.encrypt?
        elsif root_filesystem
          root_filesystem.plain_blk_devices.any? { |d| d.respond_to?(:encrypted?) && d.encrypted? }
        else
          false
        end
      end

      # Whether the root (/) filesystem is going to be Btrfs
      def btrfs_root?
        if root_planned_dev
          root_planned_dev.respond_to?(:filesystem_type) && root_planned_dev.filesystem_type.is?(:btrfs)
        elsif root_filesystem
          root_filesystem.type.is?(:btrfs)
        else
          false
        end
      end

      # Whether the partition table of the disk used for booting matches the
      # given type.
      # @see #boot_disk
      def boot_ptable_type?(type)
        return false if boot_ptable_type.nil?
        boot_ptable_type.is?(type)
      end

    protected

      attr_reader :devicegraph
      attr_reader :planned_devices
      attr_reader :boot_disk_name
      attr_reader :root_planned_dev
      attr_reader :root_filesystem

      def boot_ptable_type
        return nil unless boot_disk
        return boot_disk.partition_table.type unless boot_disk.partition_table.nil?

        # If the disk end up being used, there will be a partition table on it
        boot_disk.preferred_ptable_type
      end

      # TODO: handle planned LV (not needed so far)
      def boot_disk_from_planned_dev
        return nil unless root_planned_dev
        return nil unless root_planned_dev.respond_to?(:disk)

        devicegraph.disks.detect { |d| d.name == root_planned_dev.disk }
      end

      def boot_disk_from_devicegraph
        return nil unless root_filesystem
        root_filesystem.ancestors.detect { |d| d.is?(:disk) }
      end
    end
  end
end
