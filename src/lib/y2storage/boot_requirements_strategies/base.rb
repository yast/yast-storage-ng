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
require "yast/i18n"
require "y2storage/disk_size"
require "y2storage/filesystems/type"
require "y2storage/planned"
require "y2storage/boot_requirements_strategies/analyzer"
require "y2storage/exceptions"
require "y2storage/volume_specification"
require "y2storage/setup_error"

module Y2Storage
  module BootRequirementsStrategies
    class Error < Y2Storage::Error
    end

    # Base class for the strategies used to calculate the boot partitioning
    # requirements
    class Base
      include Yast::Logger
      include Yast::I18n
      extend Forwardable

      def_delegators :@analyzer,
        :root_filesystem, :boot_disk, :root_in_lvm?, :root_in_software_raid?,
        :encrypted_root?, :btrfs_root?, :boot_ptable_type?, :free_mountpoint?

      # Constructor
      #
      # @see [BootRequirementsChecker#devicegraph]
      # @see [BootRequirementsChecker#planned_devices]
      # @see [BootRequirementsChecker#boot_disk_name]
      def initialize(devicegraph, planned_devices, boot_disk_name)
        textdomain "storage"

        @devicegraph = devicegraph
        @analyzer = Analyzer.new(devicegraph, planned_devices, boot_disk_name)
      end

      # Partitions that should be created to boot the system
      #
      # @param target [Symbol] :desired, :min
      #
      # @return [Array<Planned::Partition>]
      def needed_partitions(target)
        planned_partitions = []
        planned_partitions << boot_partition(target) if boot_partition_needed? && boot_partition_missing?
        planned_partitions
      end

      # All boot warnings detected in the setup, for example, when required partition is too small
      #
      # @note This method should be overloaded for derived classes.
      #
      # @see SetupError
      #
      # @return [Array<SetupError>]
      def warnings
        []
      end

      # All fatal boot errors detected in the setup, for example, when a / partition
      # is missing
      #
      # @note This method can be overloaded for derived classes.
      #
      # @see SetupError
      #
      # @return [Array<SetupError>]
      def errors
        res = []
        if root_filesystem_missing?
          error_message = _("There is no device mounted at '/'")
          res << SetupError.new(message: error_message)
        end

        res
      end

    protected

      # @return [Devicegraph]
      attr_reader :devicegraph

      # @return [BootRequirementsStrategies::Analyzer]
      attr_reader :analyzer

      # Whether there is not root
      #
      # @return [Boolean] true if there is no root; false otherwise.
      def root_filesystem_missing?
        root_filesystem.nil?
      end

      def boot_partition_needed?
        false
      end

      def boot_partition_missing?
        free_mountpoint?("/boot")
      end

      # @return [VolumeSpecification]
      def boot_volume
        return @boot_volume unless @boot_volume.nil?

        @boot_volume = VolumeSpecification.new({})
        @boot_volume.mount_point = "/boot"
        @boot_volume.fs_types = Filesystems::Type.root_filesystems
        @boot_volume.fs_type = Filesystems::Type::EXT4
        @boot_volume.min_size = DiskSize.MiB(100)
        @boot_volume.desired_size = DiskSize.MiB(200)
        @boot_volume.max_size = DiskSize.MiB(500)
        @boot_volume
      end

      # @return [Planned::Partition]
      def boot_partition(target)
        planned_partition = create_planned_partition(boot_volume, target)
        planned_partition.disk = boot_disk.name
        planned_partition
      end

      # Create a planned partition from a volume specification
      #
      # @param volume [VolumeSpecification]
      # @param target [Symbol] :desired, :min
      #
      # @return [VolumeSpecification]
      def create_planned_partition(volume, target)
        planned_partition = Planned::Partition.new(volume.mount_point, volume.fs_type)
        planned_partition.min_size = target == :min ? volume.min_size : volume.desired_size
        planned_partition.max_size = volume.max_size
        planned_partition.partition_id = volume.partition_id
        planned_partition.weight = analyzer.max_planned_weight || 0.0
        planned_partition
      end

      # Whether there is no partition that matches the volume
      #
      # @param volume [VolumeSpecification]
      # @return [Boolean] true if there is no partition; false otherwise.
      def missing_partition_for?(volume)
        Partition.all(devicegraph).none? { |p| p.match_volume?(volume) }
      end

      # Specific error when the boot disk cannot be detected
      #
      # @return [SetupError]
      def unknown_boot_disk_error
        # TRANSLATORS: error message
        error_message = _("Boot requirements cannot be determined because there is no '/' mount point")
        SetupError.new(message: error_message)
      end
    end
  end
end
