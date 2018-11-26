# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require "y2storage/boot_requirements_strategies/uefi"
require "y2storage/existing_filesystem"

module Y2Storage
  module BootRequirementsStrategies
    # Strategy to calculate boot requirements for Raspberry Pi (a.k.a. raspi)
    # systems
    #
    # (open)SUSE approach for booting Raspberry Pi devices is using a firmware
    # located in a separate partition that makes the raspi basically work
    # as a normal PC-like UEFI system. For details, see fate#323484 and
    # https://www.suse.com/media/article/UEFI_on_Top_of_U-Boot.pdf
    # So this is just a special case of UEFI boot in which the firmware
    # partition must be kept (and mounted to allow updating its content).
    class Raspi < UEFI
      RPI_BOOT_MOUNT_PATH = "/boot/vc"
      private_constant :RPI_BOOT_MOUNT_PATH

      # Constructor, see base class
      def initialize(*args)
        textdomain "storage"
        super
      end

      # @see Base#needed_partitions
      def needed_partitions(target)
        planned_partitions = super

        if free_mountpoint?(RPI_BOOT_MOUNT_PATH) && reusable_rpi_boot
          planned = Planned::Partition.new(RPI_BOOT_MOUNT_PATH)
          planned.reuse_name = reusable_rpi_boot.name
          planned_partitions << planned
        end

        planned_partitions
      end

    protected

      # System partition containing an usable Raspberry Pi boot code.
      #
      # According to fate#323484 and to the "UEFI on Top of U-Boot" paper
      # (https://www.suse.com/media/article/UEFI_on_Top_of_U-Boot.pdf),
      # the Raspberry Pi boot code resides in a file called "bootcode.bin" that
      # is placed in the first partition of a partition table of type MBR. That
      # partition must be of type DOS32 (id 0xC) and formatted as VFAT.
      #
      # FIXME: this involves mounting some of the appealing partitions (first
      # FAT partition in a MBR partition table) to check whether the boot code
      # is actually there. Thus, caching the result for the whole life of the
      # (probed) devicegraph would be desirable.
      #
      # @return [Partition, nil] nil if no suitable partition is found
      def reusable_rpi_boot
        return @reusable_rpi_boot if @reusable_rpi_checked

        @reusable_rpi_checked = true

        # First check if there is a firmware partition in the target disk
        @reusable_rpi_boot = suitable_rpi_boot(boot_disk)
        return @reusable_rpi_boot if @reusable_rpi_boot

        # If not, any firmware partition we can find
        devicegraph.disk_devices.each do |disk|
          @reusable_rpi_boot = suitable_rpi_boot(disk)
          return @reusable_rpi_boot if @reusable_rpi_boot
        end

        nil
      end

      # Partition in the given disk containing an usable Raspberry Pi
      # boot code.
      #
      # @see #reusable_rpi_boot
      #
      # @param disk [Partitionable] disk to analyze
      # @return [Partition, nil] nil if no suitable partition is found
      def suitable_rpi_boot(disk)
        return nil unless disk.partition_table && disk.partition_table.type.is?(:msdos)

        partition = disk.partitions.sort_by { |p| p.region.start }.first
        # In our experience, partition ids are too often set to a wrong value
        # and even the firmwares are kind of relaxed about the ids they accept
        # for a given purpose.
        # So, for the time being, let's skip the check for partition.id.is?(:dos32)
        return nil if partition.nil?

        rpi_boot?(partition) ? partition : nil
      end

      # @see #suitable_rpi_boot
      #
      # @return [Boolean]
      def rpi_boot?(partition)
        filesystem = partition.direct_blk_filesystem
        return false if filesystem.nil? || !filesystem.type.is?(:vfat)

        ExistingFilesystem.new(filesystem).rpi_boot?
      end
    end
  end
end
