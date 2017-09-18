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
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Sequences
    # This class stores information about a filesystem being created or modified
    # and takes care of updating the devicegraph when needed, so the different
    # dialogs can always work directly on a BlkFilesystem object correctly
    # placed in the devicegraph.
    class FilesystemController
      # @return [Symbol]
      attr_accessor :role

      # @return [Boolean] whether the user wants to encrypt the device
      attr_accessor :encrypt

      # @return [String] password for the encryption device
      attr_accessor :encrypt_password

      # return [String]
      attr_reader :blk_device_name

      DEFAULT_FS = Y2Storage::Filesystems::Type::BTRFS
      DEFAULT_HOME_FS = Y2Storage::Filesystems::Type::XFS
      DEFAULT_PARTITION_ID = Y2Storage::PartitionId::LINUX
      private_constant :DEFAULT_FS, :DEFAULT_HOME_FS, :DEFAULT_PARTITION_ID

      def initialize(device)
        @blk_device_name = device.name
        @encrypt = blk_device.encrypted?
        @initial_graph = working_graph.dup
      end

      def blk_device
        Y2Storage::BlkDevice.find_by_name(working_graph, blk_device_name)
      end

      def filesystem
        blk_device.filesystem
      end

      def filesystem_type
        filesystem ? filesystem.type : nil
      end

      def to_be_formatted?
        return false if filesystem.nil?
        new?(filesystem)
      end

      def to_be_encrypted?
        return false unless can_change_encrypt?
        encrypt && !blk_device.encrypted?
      end

      def mount_point
        filesystem ? filesystem.mountpoint : nil
      end

      def partition_id
        blk_device.is?(:partition) ? blk_device.id : nil
      end

      def apply_role
        delete_filesystem
        @encrypt = false

        fs_type = mount_point = mount_by = nil

        case role
        when :swap
          part_id = Y2Storage::PartitionId::SWAP
          fs_type = Y2Storage::Filesystems::Type::SWAP
          mount_point = "swap"
          mount_by = Y2Storage::Filesystems::MountByType::DEVICE
        when :efi_boot
          part_id = Y2Storage::PartitionId::ESP
          fs_type = Y2Storage::Filesystems::Type::VFAT
          mount_point = "/boot/efi"
        when :raw
          part_id = Y2Storage::PartitionId::LVM
        else
          part_id = DEFAULT_PARTITION_ID
          fs_type = (role == :system) ? DEFAULT_FS : DEFAULT_HOME_FS
        end

        self.partition_id = part_id

        return unless fs_type

        create_filesystem(fs_type)
        assign_fs_attrs(mountpoint: mount_point, mount_by: mount_by)
      end

      def new_filesystem(type)
        # Make sure type has the correct... well, type :-)
        type = Y2Storage::Filesystems::Type.new(type)

        # It's kind of expected that these attributes are preserved when
        # changing the filesystem type, with the exceptions below
        mount_point = current_value_for(:mount_point)
        mount_by = current_value_for(:mount_by)
        label = current_value_for(:label)

        if type.is?(:swap)
          mount_point = "swap"
        elsif mount_point == "swap"
          mount_point = ""
        end

        @backup_graph = working_graph.dup if filesystem && !new?(filesystem)

        delete_filesystem
        create_filesystem(type)
        assign_fs_attrs(mount_by: mount_by, mountpoint: mount_point, label: label)
        self.partition_id = filesystem.type.default_partition_id
      end

      def dont_format
        return if filesystem.nil?
        return unless new?(filesystem)

        if @backup_graph
          restore_filesystem
        else
          delete_filesystem
        end
      end

      def partition_id=(partition_id)
        return unless blk_device.is?(:partition)
        return if partition_id.nil?

        # Make sure partition_id has the correct type
        partition_id = Y2Storage::PartitionId.new(partition_id)
        ptable = blk_device.partition_table
        blk_device.id = ptable.partition_id_for(partition_id)
      end

      def finish
        return unless can_change_encrypt?

        if to_be_encrypted?
          name = Y2Storage::Encryption.dm_name_for(blk_device)
          enc = blk_device.force_encryption(name, working_graph)
          enc.password = encrypt_password
        elsif blk_device.encrypted? && !encrypt
          blk_device.remove_encryption(working_graph)
        end
      end

    private

      def working_graph
        DeviceGraphs.instance.current
      end

      def can_change_encrypt?
        filesystem.nil? || new?(filesystem)
      end

      def new?(device)
        !device.exists_in_devicegraph?(@initial_graph)
      end

      def delete_filesystem
        blk_device.remove_descendants
      end

      def create_filesystem(type)
        blk_device.create_blk_filesystem(type)
      end

      def restore_filesystem
        mount_by = filesystem.mount_by
        mountpoint = filesystem.mountpoint
        label = filesystem.label

        @backup_graph.copy(working_graph)
        @backup_graph = nil
        @encrypt = blk_device.encrypted?

        assign_fs_attrs(mount_by: mount_by, mountpoint: mountpoint, label: label)
      end

      def assign_fs_attrs(attrs = {})
        attrs.each_pair do |attr, value|
          filesystem.send(:"#{attr}=", value) unless value.nil?
        end
      end

      def current_value_for(attribute)
        return nil if filesystem.nil?

        case attribute
        when :mount_by
          filesystem.mount_by
        when :mount_point
          filesystem.mount_point
        when :label
          # Copying the label from the filesystem in the disk looks unexpected
          new?(filesystem) ? filesystem.label : nil
        end
      end
    end
  end
end
