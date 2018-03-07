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
require "pathname"
require "y2storage/planned"

module Y2Storage
  module BootRequirementsStrategies
    # Auxiliary class that takes information from several sources (current
    # devicegraph, already planned devices and user input) and provides useful
    # information (regarding calculation of boot requirements) about the
    # expected final system.
    class Analyzer
      # Devices that are already planned to be added to the starting devicegraph.
      # @return [Array<Planned::Device>]
      attr_reader :planned_devices

      # @return [Filesystems::Base, nil] nil if there is not filesystem for root
      attr_reader :root_filesystem

      # Constructor
      #
      # @param devicegraph     [Devicegraph] starting situation.
      # @param planned_devices [Array<Planned::Device>] devices that are already planned to be
      #   added to the starting devicegraph.
      # @param boot_disk_name  [String, nil] device name of the disk that the system will try to
      #   boot first. Only useful in some scenarios like legacy boot. See {#boot_disk}.
      def initialize(devicegraph, planned_devices, boot_disk_name)
        @devicegraph = devicegraph
        @planned_devices = planned_devices
        @boot_disk_name = boot_disk_name

        @root_planned_dev = planned_for_mountpoint("/")
        @root_filesystem = filesystem_for_mountpoint("/")
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
          @boot_disk = devicegraph.disk_devices.find { |d| d.name == boot_disk_name }
        end

        @boot_disk ||= boot_disk_from_planned_dev
        @boot_disk ||= boot_disk_from_devicegraph
        @boot_disk ||= devicegraph.disk_devices.first

        @boot_disk
      end

      # Whether the root (/) filesystem is going to be in a LVM logical volume
      #
      # @return [Boolean] true if the root filesystem is going to be in a LVM
      #   logical volume. False if the root filesystem is unknown (not in the
      #   planned devices or in the devicegraph) or is not placed in a LVM.
      def root_in_lvm?
        in_lvm?(device_for_root)
      end

      # Whether the root (/) filesystem is over a Software RAID
      #
      # @return [Boolean] true if the root filesystem is going to be in a
      #   Software RAID. False if the root filesystem is unknown (not in the
      #   planned devices or in the devicegraph) or is not placed over a Software
      #   RAID.
      def root_in_software_raid?
        in_software_raid?(device_for_root)
      end

      # Whether the root (/) filesystem is going to be in an encrypted device
      #
      # @return [Boolean] true if the root filesystem is going to be in an
      #   encrypted device. False if the root filesystem is unknown (not in the
      #   planned devices or in the devicegraph) or is not encrypted.
      def encrypted_root?
        encrypted?(device_for_root)
      end

      # Whether the root (/) filesystem is going to be Btrfs
      #
      # @return [Boolean] true if the root filesystem is going to be Btrfs.
      #   False if the root filesystem is unknown (not in the planned devices
      #   or in the devicegraph) or is not Btrfs.
      def btrfs_root?
        type = filesystem_type(device_for_root)
        type ? type.is?(:btrfs) : false
      end

      # Whether the partition table of the disk used for booting matches the
      # given type.
      #
      # If the disk does not have a partition table, a GPT one will be assumed
      # since it is the default type used in the proposal.
      #
      # @return [Boolean] true if the partition table matches.
      #
      # @see #boot_disk
      def boot_ptable_type?(type)
        return false if boot_ptable_type.nil?
        boot_ptable_type.is?(type)
      end

      # Whether the passed path is not already used as mount point by any planned
      # device or by any device in the devicegraph
      #
      # @param path [String] mount point to check for
      # @return [Boolean]
      def free_mountpoint?(path)
        # FIXME: This method takes into account all mount points, even for filesystems over a
        # logical volume, software raid or a directly formatted disk. That check could produce
        # false possitives due to the presence of a mount point is not enough
        # (e.g., /boot/efi over a logical volume is not valid for booting).
        planned_for_mountpoint(path).nil? && filesystem_for_mountpoint(path).nil?
      end

      # Subset of the planned devices that are suitable as PReP
      #
      # @return [Array<Planned::Partition>]
      def planned_prep_partitions
        planned_partitions_with_id(PartitionId::PREP)
      end

      # Subset of the planned devices that are suitable as BIOS boot partitions
      #
      # @return [Array<Planned::Partition>]
      def planned_grub_partitions
        planned_partitions_with_id(PartitionId::BIOS_BOOT)
      end

      # Max weight from all the devices that were planned in advance
      #
      # @see #planned_devices
      #
      # @return [Float]
      def max_planned_weight
        @max_planned_weight ||= planned_devices.map { |dev| planned_weight(dev) }.compact.max
      end

      # Whether there is /boot/efi filesystem in a software raid
      #
      # @return [Boolean] false if there is no /boot/efi or it's not located in
      #   an MD RAID
      def efi_in_md_raid1?
        filesystem = filesystem_for_mountpoint("/boot/efi")
        return false unless filesystem

        raid = filesystem.ancestors.find { |dev| dev.is?(:software_raid) }
        return false unless raid

        return raid.md_level.is?(:raid1)
      end

    protected

      attr_reader :devicegraph
      attr_reader :boot_disk_name
      attr_reader :root_planned_dev

      # Device (planned or from the devicegraph) containing the "/" mount point
      #
      # @see #planned_devices
      # @see #devicegraph
      #
      # @return [Filesystems::Base, Planned::Device, nil] nil if there is no
      #   mount point or plan for "/"
      def device_for_root
        root_planned_dev || root_filesystem || nil
      end

      def boot_ptable_type
        return nil unless boot_disk
        return boot_disk.partition_table.type unless boot_disk.partition_table.nil?

        # If the disk end up being used, there will be a partition table on it
        boot_disk.preferred_ptable_type
      end

      # TODO: handle planned LV (not needed so far)
      def boot_disk_from_planned_dev
        # FIXME: This method is only able to find the boot disk when the planned
        # root is over a partition. This could not work properly in autoyast when
        # root is planned over logical volumes or software raids.
        return nil unless root_planned_dev
        return nil unless root_planned_dev.respond_to?(:disk)

        devicegraph.disk_devices.find { |d| d.name == root_planned_dev.disk }
      end

      def boot_disk_from_devicegraph
        # FIXME: In case root filesystem is over a multidevice (vg, software raid),
        # the first disk is considered the boot disk. This could not work properly
        # for some scenarios.
        return nil unless root_filesystem
        root_filesystem.ancestors.find { |d| d.is?(:disk_device) }
      end

      def planned_partitions_with_id(id)
        planned_devices.select do |dev|
          dev.is_a?(Planned::Partition) && dev.partition_id == id
        end
      end

      # Planned device with the given mount point, if any
      #
      # @see #planned_devices
      #
      # @param path [String] mount point to check for
      # @return [Planned::Device, nil] nil if no separate device is planned for
      #   the mount point
      def planned_for_mountpoint(path)
        cleanpath = Pathname.new(path).cleanpath
        planned_devices.find do |dev|
          next false unless dev.respond_to?(:mount_point) && dev.mount_point
          Pathname.new(dev.mount_point).cleanpath == cleanpath
        end
      end

      # Filesystem in the devicegraph with the given mount point, if any
      #
      # @see #devicegraph
      #
      # @param path [String] mount point to check for
      # @return [Filesystems::Base, nil] nil if there is no filesystem to be
      #   mounted there
      def filesystem_for_mountpoint(path)
        cleanpath = Pathname.new(path).cleanpath
        devicegraph.filesystems.find do |fs|
          fs.mount_path && Pathname.new(fs.mount_path).cleanpath == cleanpath
        end
      end

      # Weight of a planned device, nil if none or not supported
      #
      # @return [Float, nil]
      def planned_weight(device)
        device.respond_to?(:weight) ? device.weight : nil
      end

      # Filesystem type used for the device
      #
      # The device can be a planned one or filesystem from the devicegraph.
      #
      # @param device [Filesystems::Base, Planned::Device, nil]
      # @return [Filesystems::Type, nil] nil if device is nil or is a planned
      #   device not going to be formatted
      def filesystem_type(device)
        return nil if device.nil?

        device.respond_to?(:filesystem_type) ? device.filesystem_type : device.type
      end

      # Whether the device is in a LVM logical volume
      #
      # The device can be a planned one or filesystem from the devicegraph.
      #
      # @param device [Filesystems::Base, Planned::Device, nil]
      # @return [Boolean] false if device is nil
      def in_lvm?(device)
        return false if device.nil?

        if device.is_a?(Planned::Device)
          device.is_a?(Planned::LvmLv)
        else
          device.plain_blk_devices.any? { |dev| dev.is?(:lvm_lv) }
        end
      end

      # Whether the device is encrypted
      #
      # The device can be a planned one or filesystem from the devicegraph.
      #
      # @param device [Filesystems::Base, Planned::Device, nil]
      # @return [Boolean] false if device is nil
      def encrypted?(device)
        return false if device.nil?

        if device.is_a?(Planned::Device)
          device.respond_to?(:encrypt?) && device.encrypt?
        else
          device.plain_blk_devices.any? { |d| d.respond_to?(:encrypted?) && d.encrypted? }
        end
      end

      # Whether the device is in a software RAID
      #
      # The device can be a planned one or filesystem from the devicegraph.
      #
      # @param device [Filesystems::Base, Planned::Device, nil]
      # @return [Boolean] false if device is nil
      def in_software_raid?(device)
        return false if device.nil?

        if device.is_a?(Planned::Device)
          device.is_a?(Planned::Md)
        else
          device.ancestors.any? { |dev| dev.is?(:software_raid) }
        end
      end
    end
  end
end
