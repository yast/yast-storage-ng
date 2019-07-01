# Copyright (c) [2015-2019] SUSE LLC
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
      # disk hosting /boot or the first disk hosting the root filesystem is
      # considered to be the boot disk.
      #
      # If "/boot" or "/" are still not present neither in the devicegraph nor
      # in the list of planned devices, the first disk of the system is used as
      # fallback.
      #
      # FIXME: For RAID and LVM setups a list of disks would strictly be
      #   correct (the disks that constitute the /boot file system).
      #   The current approach is not that bad, though, as we don't have to
      #   actually install the bootloader but just check if it will work.
      #   Also, the extra partitions proposed are the *minimum* required to boot.
      #
      #   But particularly in asymmetric cases (like part of LVM on a GPT
      #   disk, part on a MS-DOS disk) we have a problem: the requirements
      #   will differ depending on which boot disk is picked (basically
      #   random). For this to work properly we'd have to switch to tracking
      #   all boot disks but this will also mean error messages like "BIOS
      #   Boot on sda and (or?) MBR-GAP on sdb are missing".
      #
      # @return [Disk]
      def boot_disk
        return @boot_disk if @boot_disk

        @boot_disk = devicegraph.disk_devices.find { |d| d.name == boot_disk_name } if boot_disk_name

        @boot_disk ||= boot_disk_from_planned_dev
        @boot_disk ||= boot_disk_from_devicegraph
        @boot_disk ||= devicegraph.disk_devices.first
        @boot_disk = boot_disk_raid1(@boot_disk) || @boot_disk

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

      # Whether the filesystem containing /boot is going to be in a LVM logical volume
      #
      # @return [Boolean] true if the filesystem where /boot resides is going to
      #   be in an LVM logical volume. False if such filesystem is unknown (not
      #   in the planned devices or in the devicegraph) or is not placed in an LVM.
      def boot_in_lvm?
        in_lvm?(device_for_boot)
      end

      # Whether the filesystem containing /boot is over a Software RAID
      #
      # @return [Boolean] true if the filesystem where /boot resides is going to
      #   be in a Software RAID. False if such filesystem is unknown (not in the
      #   planned devices or in the devicegraph) or is not placed over a
      #   Software RAID.
      def boot_in_software_raid?
        in_software_raid?(device_for_boot)
      end

      # Whether the filesystem containing /boot is going to be in an encrypted device
      #
      # @return [Boolean] true if the filesystem where /boot resides is going to
      #   be in an encrypted device. False if such filesystem is unknown (not in
      #   the planned devices or in the devicegraph) or is not encrypted.
      def encrypted_boot?
        encrypted?(device_for_boot)
      end

      # Whether the EFI system partition (/boot/efi) is in a LVM logical volume
      #
      # @return [Boolean] true if the filesystem where /boot/efi resides is going to
      #   be in an LVM logical volume. False if such filesystem is unknown
      #   or is not placed in an LVM.
      def esp_in_lvm?
        in_lvm?(esp_filesystem)
      end

      # Whether the EFI system partition (/boot/efi) is over a Software RAID
      #
      # @return [Boolean] true if the filesystem where /boot/efi resides is going to
      #   be in a Software RAID. False if such filesystem is unknown or is
      #   not placed over a Software RAID.
      def esp_in_software_raid?
        in_software_raid?(esp_filesystem)
      end

      # Whether the EFI system partition (/boot/efi) is over a Software RAID1
      #
      # This setup can be used to ensure the system can boot from any of the
      # disks in the RAID, but it's not fully reliable.
      # See bsc#1081578 and the related FATE#322485 and FATE#314829.
      #
      # @return [Boolean] false if there is no /boot/efi or it's not located in
      #   an MD mirror RAID
      def esp_in_software_raid1?
        filesystem = esp_filesystem
        return false if !filesystem

        filesystem.ancestors.any? do |dev|
          # see comment in #in_software_raid?
          dev != boot_disk && dev.is?(:software_raid) && dev.md_level.is?(:raid1)
        end
      end

      # Whether the EFI system partition (/boot/efi) is in an encrypted device
      #
      # @return [Boolean] true if the filesystem where /boot/efi resides is going to
      #   be in an encrypted device. False if such filesystem is unknown or
      #   is not encrypted.
      def encrypted_esp?
        encrypted?(esp_filesystem)
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

      # Whether grub can be embedded into the boot (/boot) filesystem
      #
      # @return [Boolean] true if grub can be embedded into the boot filesystem.
      #   False if the boot filesystem is unknown (not in the planned devices
      #   or in the devicegraph) or can not embed grub.
      def boot_fs_can_embed_grub?
        type = boot_filesystem_type
        type ? type.grub_ok? : false
      end

      # Whether grub can be embedded into the root (/) filesystem
      #
      # @return [Boolean] true if grub can be embedded into the root filesystem.
      #   False if the root filesystem is unknown (not in the planned devices
      #   or in the devicegraph) or can not embed grub.
      def root_fs_can_embed_grub?
        type = filesystem_type(device_for_root)
        type ? type.grub_ok? : false
      end

      # Type of the filesystem (planned or from the devicegraph) containing /boot
      #
      # @return [Filesystems::Type, nil] nil if there is no place for /boot either
      #   in the planned devices or in the devicegraph
      def boot_filesystem_type
        filesystem_type(device_for_boot)
      end

      # Whether the partition table of the disk used for booting matches the
      # given type.
      #
      # It is possible to check for 'no partition table' by passing type nil.
      #
      # @return [Boolean] true if the partition table matches.
      #
      # @see #boot_disk
      def boot_ptable_type?(type)
        return type.nil? if boot_ptable_type.nil?
        return false if type.nil?

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

      # Method to return all prep partitions - newly created and also reused from graph.
      # It is useful to do checks on top of that partitions
      # @note to get all prep partition, from graph and planned use
      #   `graph_prep_partitions + planned_prep_partitions`
      def graph_prep_partitions
        devicegraph.partitions.select do |partition|
          partition.id.is?(:prep)
        end
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

      # Device (planned or from the devicegraph) containing the "/" path
      #
      # It can be a device directly mounted there or the root device if
      # "/boot" is not a separate mount point.
      #
      # @see #planned_devices
      # @see #devicegraph
      #
      # @return [Filesystems::Base, Planned::Device, nil] nil if there is no
      #   filesystem or plan for anything containing "/boot"
      def device_for_boot
        boot_planned_dev || boot_filesystem || root_planned_dev || root_filesystem || nil
      end

      # Partition table type of boot disk
      #
      # @return [PartitionTables::Type, nil] partition table type of boot disk or nil
      #   if it doesn't have a partition table
      def boot_ptable_type
        boot_disk.partition_table.type if boot_disk && !boot_disk.partition_table.nil?
      end

      # TODO: handle planned LV (not needed so far)
      def boot_disk_from_planned_dev
        # FIXME: This method is only able to find the boot disk when the planned
        # root is over a partition. This could not work properly in autoyast when
        # root is planned over logical volumes or software raids.
        planned_dev = [boot_planned_dev, root_planned_dev].find do |planned|
          planned&.respond_to?(:disk)
        end

        return nil unless planned_dev

        devicegraph.disk_devices.find { |d| d.name == planned_dev.disk }
      end

      def boot_disk_from_devicegraph
        # FIXME: In case root filesystem is over a multidevice (vg, software raid),
        # the first disk is considered the boot disk. This could not work properly
        # for some scenarios.
        filesystem = boot_filesystem || root_filesystem

        return nil unless filesystem

        filesystem_container(filesystem)
      end

      # Disk device that contains the filesystem
      #
      # Note that for a filesystem created over Bcache, the devices of the caching set
      # must be discarded as possible containers. But, in case of Flash-only Bcache, the
      # container is the device used for the caching set.
      #
      # @param filesystem [Y2Storage::Filesystems::Base]
      # @return [Y2Storage::BlkDevice] disk device holding the filesystem
      def filesystem_container(filesystem)
        ancestors = filesystem.ancestors

        bcache = ancestors.find { |d| d.is?(:bcache) }

        if bcache && !bcache.flash_only?
          backing_device = bcache.backing_device
          ancestors = [backing_device] + backing_device.ancestors
        end

        ancestors.find { |d| d.is?(:disk_device) }
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
        devicegraph.filesystems.find do |fs|
          fs.mount_point&.path?(path)
        end
      end

      # Weight of a planned device, nil if none or not supported
      #
      # @return [Float, nil]
      def planned_weight(device)
        device.respond_to?(:weight) ? device.weight : nil
      end

      # Planned device for a separate /boot
      #
      # @return [Planned::Device, nil] nil if no separate /boot is planned
      def boot_planned_dev
        @boot_planned_dev ||= planned_for_mountpoint("/boot")
      end

      # Filesystem mounted at /boot
      #
      # @return [Filesystems::Base, nil] nil if there is no separate filesystem for /boot
      def boot_filesystem
        @boot_filesystem ||= filesystem_for_mountpoint("/boot")
      end

      # Filesystem mounted at /boot/efi
      #
      # @return [Filesystems::Base, nil] nil if there is no separate filesystem for /boot/efi
      def esp_filesystem
        @esp_filesystem ||= filesystem_for_mountpoint("/boot/efi")
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
          device.ancestors.any? do |dev|
            # Don't check boot_disk as it might validly be a RAID1 itself
            # (full disks as RAID case) - we want to treat this as 'no RAID'.
            dev.is?(:software_raid) && dev != boot_disk
          end
        end
      end

      # Check if device is a direct member of a RAID1 (RAID over entire disks).
      #
      # FIXME: The check is possibly overly strict: currently it enforces
      #   that the disk is a member of a single RAID.
      #   That might not be necessary.
      #
      # @return [Y2Storage::Md, nil] the RAID device, else nil
      def boot_disk_raid1(device)
        return nil if device.nil?

        raid1_dev = nil
        device.children.each do |raid|
          next if !raid.is?(:software_raid)
          return nil if !raid.md_level.is?(:raid1)
          return nil if raid1_dev && raid1_dev != raid

          raid1_dev = raid
        end

        raid1_dev
      end
    end
  end
end
