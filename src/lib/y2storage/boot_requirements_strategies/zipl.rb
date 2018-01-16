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

require "y2storage/boot_requirements_strategies/base"

module Y2Storage
  module BootRequirementsStrategies
    # Strategy to calculate boot requirements in systems using ZIPL
    class ZIPL < Base
      # @see Base#needed_partitions
      def needed_partitions(target)
        raise Error, "Impossible to boot system from the chosen disk" unless supported_boot_disk?
        zipl_partition_missing? ? [zipl_partition(target)] : []
      end

      # Boot errors in the current setup
      #
      # @return [Array<SetupError>]
      def errors
        errors = super

        if root_filesystem_missing?
          errors << unknown_boot_disk_error
        elsif !supported_boot_disk?
          errors << unsupported_boot_disk_error
        elsif missing_partition_for?(zipl_volume)
          errors << SetupError.new(missing_volume: zipl_volume)
        end

        errors
      end

    protected

      def supported_boot_disk?
        return false unless boot_disk
        if boot_disk.is?(:dasd)
          return false if boot_disk.type.is?(:fba)
          return false if boot_disk.format.is?(:ldl)
          # TODO: DIAG disks (whatever they are) are not supported either
        end
        true
      end

      def zipl_partition_missing?
        free_mountpoint?("/boot/zipl")
      end

      # @return [VolumeSpecification]
      def zipl_volume
        return @zipl_volume unless @zipl_volume.nil?

        @zipl_volume = VolumeSpecification.new({})
        @zipl_volume.mount_point = "/boot/zipl"
        @zipl_volume.fs_types = Filesystems::Type.zipl_filesystems
        @zipl_volume.fs_type = Filesystems::Type.zipl_filesystems.first
        @zipl_volume.min_size = DiskSize.MiB(100)
        @zipl_volume.desired_size = DiskSize.MiB(200)
        @zipl_volume.max_size = DiskSize.GiB(1)
        @zipl_volume
      end

      # @return [Planned::Partition]
      def zipl_partition(target)
        planned_partition = create_planned_partition(zipl_volume, target)
        planned_partition.disk = boot_disk.name
        planned_partition
      end

      # Specific error when the boot disk is not valid for booting
      #
      # @return [SetupError]
      def unsupported_boot_disk_error
        # TRANSLATORS: error message
        error_message = _(
          "Looks like the system is going to be installed on a FBA " \
          "or LDL device. Booting from such device is not supported."
        )
        SetupError.new(message: error_message)
      end
    end
  end
end
