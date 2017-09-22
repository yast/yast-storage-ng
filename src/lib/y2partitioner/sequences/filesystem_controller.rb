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
require "y2storage/filesystems/btrfs"
require "y2storage/subvol_specification"

Yast.import "Mode"

module Y2Partitioner
  module Sequences
    # This class stores information about a filesystem being created or modified
    # and takes care of updating the devicegraph when needed, so the different
    # dialogs can always work directly on a BlkFilesystem object correctly
    # placed in the devicegraph.
    class FilesystemController
      # @return [Symbol] Role chosen be the user for the device
      attr_accessor :role

      # @return [Boolean] Whether the user wants to encrypt the device
      attr_accessor :encrypt

      # @return [String] Password for the encryption device
      attr_accessor :encrypt_password

      # Name of the plain device
      #
      # @see #blk_device
      # @return [String]
      attr_reader :blk_device_name

      # Type for the role "system"
      DEFAULT_FS = Y2Storage::Filesystems::Type::BTRFS
      # Type for the role "data"
      DEFAULT_HOME_FS = Y2Storage::Filesystems::Type::XFS
      DEFAULT_PARTITION_ID = Y2Storage::PartitionId::LINUX
      private_constant :DEFAULT_FS, :DEFAULT_HOME_FS, :DEFAULT_PARTITION_ID

      # @param device [Y2Storage::BlkDevice] see {#blk_device)
      def initialize(device)
        @blk_device_name = device.name
        @encrypt = blk_device.encrypted?
      end

      # Plain block device being modified, i.e. device where the filesystem is
      # located or where it will be eventually placed/removed.
      #
      # Note this is always the plain device, no matter if it is encrypted or
      # not.
      #
      # @return [Y2Storage::BlkDevice]
      def blk_device
        Y2Storage::BlkDevice.find_by_name(working_graph, blk_device_name)
      end

      # Filesystem object being modified
      #
      # @return [Y2Storage::BlkFilesystem]
      def filesystem
        blk_device.filesystem
      end

      # Type of the current filesystem
      #
      # @return [Y2Storage::Filesystems::Type, nil] nil if there is no
      #   filesystem
      def filesystem_type
        filesystem ? filesystem.type : nil
      end

      # Whether the block device will be formatted, i.e. a new filesystem will
      # be created when commiting the devicegraph.
      #
      # @return [Boolean]
      def to_be_formatted?
        return false if filesystem.nil?
        new?(filesystem)
      end

      # Whether a new encryption device will be created for the block device
      #
      # @return [Boolean]
      def to_be_encrypted?
        return false unless can_change_encrypt?
        encrypt && !blk_device.encrypted?
      end

      # Mount point of the current filesystem
      #
      # @return [string, nil] nil if there is no filesystem
      def mount_point
        filesystem ? filesystem.mountpoint : nil
      end

      # Partition id of the block device if it is a partition
      #
      # @return [Y2Storage::PartitionId, nil] nil if {#blk_device} is not a
      #   partition
      def partition_id
        blk_device.is?(:partition) ? blk_device.id : nil
      end

      # Modifies the block filesystem based on {#role}
      #
      # This creates a new filesystem object on top of the block device if
      # needed, modifies the partition id when it makes sense, etc.
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
        assign_fs_attrs(mount_by: mount_by)
        self.mount_point = mount_point
      end

      # Creates a new filesystem on top of the block device, removing the
      # previous one if any, as a result of the user choosing the option in the
      # UI to format the device.
      #
      # Some information from the previous filesystem (like the mountpoint or
      # the label) is kept in the new filesystem if it makes sense.
      #
      # @param type of the new filesystem
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
        assign_fs_attrs(mount_by: mount_by, label: label)
        self.partition_id = filesystem.type.default_partition_id
        self.mount_point = mount_point
      end

      # Makes the changes related to the option "do not format" in the UI, which
      # implies removing any new filesystem or respecting the preexisting one.
      #
      # @note With the current implementation there is a corner case that
      # doesn't work like the traditional expert partitioner. If a partition
      # preexisting in the disk is edited (e.g. replacing the filesystem with a
      # new one) and then we the user tries to edit it again, "do not format"
      # will actually mean leaving the partition unformatted, not respecting the
      # filesystem on the system.
      def dont_format
        return if filesystem.nil?
        return unless new?(filesystem)

        if @backup_graph
          restore_filesystem
        else
          delete_filesystem
        end
      end

      # Sets the partition id of the block device if it makes sense
      def partition_id=(partition_id)
        return unless blk_device.is?(:partition)
        return if partition_id.nil?

        # Make sure partition_id has the correct type
        partition_id = Y2Storage::PartitionId.new(partition_id)
        ptable = blk_device.partition_table
        blk_device.id = ptable.partition_id_for(partition_id)
      end

      # Sets the mount point of the filesystem if there is one
      #
      # Take into account that modifying the mount point can have side effects
      # if the filesystem doesn't exist yet, like changing the list of
      # subvolumes if the new or old mount point is "/".
      #
      # @param mount_point [String] new mount point
      def mount_point=(mount_point)
        return if filesystem.nil? || filesystem.mount_point == mount_point

        before_set_mount_point
        filesystem.mount_point = mount_point
        after_set_mount_point
      end

      # Applies last changes to the block device at the end of the wizard, which
      # mainly means encrypting the device or removing the encryption layer for
      # non preexisting devices.
      def finish
        return unless can_change_encrypt?

        if to_be_encrypted?
          name = Y2Storage::Encryption.dm_name_for(blk_device)
          enc = blk_device.create_encryption(name)
          enc.password = encrypt_password
        elsif blk_device.encrypted? && !encrypt
          blk_device.remove_encryption
        end
      end

      # Whether is possible to define the generic format options for the current
      # filesystem
      #
      # @return [Boolean]
      def format_options_supported?
        to_be_formatted? && !filesystem.type.is?(:btrfs)
      end

      # Whether is possible to set the snapshots configuration for the current
      # filesystem
      #
      # @see Y2Storage::Filesystems::Btrfs.configure_snapper
      #
      # @return [Boolean]
      def snapshots_supported?
        return false unless Yast::Mode.installation
        return false unless to_be_formatted?
        filesystem.root? && filesystem.respond_to?(:configure_snapper=)
      end

      # Sets configure_snapper for the filesystem if it makes sense
      #
      # @see Y2Storage::Filesystems::Btrfs.configure_snapper=
      #
      # @param value [Boolean]
      def configure_snapper=(value)
        return if filesystem.nil? || !filesystem.respond_to?(:configure_snapper)
        filesystem.configure_snapper = value
      end

      # Status of the snapshots configuration for the filesystem
      #
      # @see Y2Storage::Filesystems::Btrfs.configure_snapper
      #
      # @return [Boolean]
      def configure_snapper
        return false if filesystem.nil? || !filesystem.respond_to?(:configure_snapper)
        filesystem.configure_snapper
      end

    private

      def working_graph
        DeviceGraphs.instance.current
      end

      def system_graph
        DeviceGraphs.instance.system
      end

      def can_change_encrypt?
        filesystem.nil? || new?(filesystem)
      end

      def new?(device)
        !device.exists_in_devicegraph?(system_graph)
      end

      def delete_filesystem
        blk_device.remove_descendants
      end

      def create_filesystem(type)
        blk_device.create_blk_filesystem(type)

        if btrfs?
          default_path = Y2Storage::Filesystems::Btrfs.default_btrfs_subvolume_path
          filesystem.ensure_default_btrfs_subvolume(path: default_path)
        end
      end

      def restore_filesystem
        mount_by = filesystem.mount_by
        mount_point = filesystem.mount_point
        label = filesystem.label

        @backup_graph.copy(working_graph)
        @backup_graph = nil
        @encrypt = blk_device.encrypted?

        assign_fs_attrs(mount_by: mount_by, label: label)
        self.mount_point = mount_point
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

      def before_set_mount_point
        # When the filesystem is btrfs, the not probed subvolumes are deleted.
        delete_not_probed_subvolumes if btrfs?
      end

      def after_set_mount_point
        # When the filesystem is btrfs and root, default proposed subvolumes are added
        # in case they are not been probed.
        add_proposed_subvolumes if btrfs? && root?
        # When the filesystem is btrfs, the mount point of the resulting subvolumes is updated.
        update_mount_points if btrfs?
        # Shadowing control of btrfs subvolumes is always performed.
        Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(working_graph)
      end

      # Deletes not probed subvolumes
      def delete_not_probed_subvolumes
        loop do
          subvolume = find_not_probed_subvolume
          return if subvolume.nil?
          filesystem.delete_btrfs_subvolume(working_graph, subvolume.path)
        end
      end

      # Finds first not probed subvolume
      #
      # @note Top level and default subvolumes are not taken into account (see {#subvolumes}).
      #
      # @return [Y2Storage::BtrfsSubvolume, nil]
      def find_not_probed_subvolume
        device_graph = DeviceGraphs.instance.system
        subvolumes.detect { |s| !s.exists_in_devicegraph?(device_graph) }
      end

      # A proposed subvolume is added only when it does not exist in the filesystem and it
      # makes sense for the current architecture
      #
      # @see Y2Storage::Filesystems::Btrfs#add_btrfs_subvolumes
      def add_proposed_subvolumes
        specs = Y2Storage::SubvolSpecification.from_control_file
        specs = Y2Storage::SubvolSpecification.fallback_list if specs.nil? || specs.empty?

        filesystem.add_btrfs_subvolumes(specs)
      end

      # Updates subvolumes mount point
      #
      # @note Top level and default subvolumes are not taken into account (see {#subvolumes}).
      def update_mount_points
        subvolumes.each do |subvolume|
          subvolume.mount_point = filesystem.btrfs_subvolume_mount_point(subvolume.path)
        end
      end

      # Btrfs subvolumes without top level and default ones
      def subvolumes
        filesystem.btrfs_subvolumes.select do |subvolume|
          !subvolume.top_level? && !subvolume.default_btrfs_subvolume?
        end
      end

      def btrfs?
        filesystem.supports_btrfs_subvolumes?
      end

      def root?
        filesystem.root?
      end
    end
  end
end
