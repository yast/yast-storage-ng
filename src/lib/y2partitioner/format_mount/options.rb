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

require "yast"
require "y2storage"
require "y2partitioner/refinements/filesystem_type"

module Y2Partitioner
  module FormatMount
    # Helper class to store and remember format and mount options during
    # different dialogs avoiding the direct modification of the blk_device being
    # edited
    class Options
      using Refinements::FilesystemType

      # @return [Y2Storage::Filesystem::Type]
      attr_accessor :filesystem_type
      # @return [:system, :data, :swap, :efi_boot]
      attr_accessor :role
      # @return [Boolean]
      attr_accessor :encrypt
      # @return [Y2Storage::PartitionType]
      attr_accessor :partition_type
      # @return [Y2Storage::PartitionId]
      attr_accessor :partition_id
      # @return [String]
      attr_accessor :mount_point
      # @return [Y2Storage::Filesystems::MountBy]
      attr_accessor :mount_by
      # @return [Boolean]
      attr_accessor :format
      # @return [Boolean]
      attr_accessor :mount
      # @return [String]
      attr_accessor :name
      # @return [Array<String>]
      attr_accessor :fstab_options
      # @return [String]
      attr_accessor :password
      # @return [String]
      attr_accessor :label

      DEFAULT_MOUNT_BY = Y2Storage::Filesystems::MountByType::UUID
      DEFAULT_FS = Y2Storage::Filesystems::Type::BTRFS
      DEFAULT_HOME_FS = Y2Storage::Filesystems::Type::XFS
      DEFAULT_PARTITION_ID = Y2Storage::PartitionId::LINUX

      # Constructor
      #
      # @param options [Hash]
      # @param partition [Y2Storage::BlkDevice]
      # @param role [Symbol]
      def initialize(options: {}, partition: nil, role: nil)
        set_defaults!

        options_for_role(role) if role
        options_for_partition(partition) if partition

        @mount = @mount_point && !@mount_point.empty?

        options.each do |o, v|
          public_send("#{o}=", v) if respond_to?("#{o}=")
        end
      end

      def set_defaults!
        @format = false
        @encrypt = false
        @mount_by = DEFAULT_MOUNT_BY
        @filesystem_type = DEFAULT_FS
        @partition_id = DEFAULT_PARTITION_ID
        @fstab_options = []
      end

      # sets current attributes based on the given partition
      # @param partition [Y2Storage::BlkDevice]
      def options_for_partition(partition)
        return unless partition

        @name = partition.name
        @partition_type = partition.type
        @partition_id = partition.id

        options_for_filesystem(partition.filesystem)
      end

      # sets current filesystem attributes based on the given one
      # @param filesystem [Y2Storage::Filesystems::Type]
      def options_for_filesystem(filesystem)
        return unless filesystem

        @filesystem_type = filesystem.type
        @mount_point = filesystem.mount_point
        @mount_by = filesystem.mount_by if filesystem.mount_by
        @label = filesystem.label
        @fstab_options = filesystem.fstab_options
      end

      # FIXME: Set fstab default options for the current filesystem
      def update_filesystem_options!
        if @filesystem_type != Y2Storage::Filesystems::Type::SWAP
          @mount_point = "" if @mount_point == "swap"
        end

        # Delete options that are not supported by the current Filesystem.
        @fstab_options.keep_if do |option|
          @filesystem_type.supported_fstab_options.include?(option.gsub(/=(.*)/, "="))
        end

        @partition_id = filesystem_type.default_partition_id || DEFAULT_PARTITION_ID
      end

      # Initializes the format and mount state based on the role given.
      #
      # @param role [Symbol]
      def options_for_role(role)
        case role
        when :swap
          @mount_point = "swap"
          @filesystem_type = Y2Storage::Filesystems::Type::SWAP
          @partition_id = Y2Storage::PartitionId::SWAP
          @mount_by = Y2Storage::Filesystems::MountByType::DEVICE
        when :efi_boot
          @mount_point = "/boot/efi"
          @partition_id = Y2Storage::PartitionId::ESP
          @filesystem_type = Y2Storage::Filesystems::Type::VFAT
        when :raw
          @partition_id = Y2Storage::PartitionId::LVM
        else
          @mount_point = ""
          @filesystem = (role == :system) ? DEFAULT_FS : DEFAULT_HOME_FS
          @partition_id = DEFAULT_PARTITION_ID
        end

        @role = role
      end

      # @param partition_id [Y2Storage::PartitionId]
      def options_for_partition_id(partition_id)
        case partition_id
        when Y2Storage::PartitionId::SWAP
          options_for_role(:swap)
        when Y2Storage::PartitionId::ESP
          options_for_role(:efi_boot)
        when partition_id.is?(:windows_system)
          @filesystem_type = Y2Storage::Filesystems::Type::VFAT
        else
          @filesystem_type = partition_id.formattable? ? DEFAULT_FS : nil
        end
      end
    end
  end
end
