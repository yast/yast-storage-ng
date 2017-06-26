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
require "y2storage/autoinst_profile/section_with_attributes"

module Y2Storage
  module AutoinstProfile
    # Thin object oriented layer on top of a <partition> section of the
    # AutoYaST profile.
    #
    # More information can be found in the 'Partitioning' section ('Partition
    # Configuration' subsection) of the AutoYaST documentation:
    # https://www.suse.com/documentation/sles-12/singlehtml/book_autoyast/book_autoyast.html#ay.partition_configuration
    # Check that document for details about the semantic of every attribute.
    class PartitionSection < SectionWithAttributes
      # Literal historically used at AutoinstPartPlan
      CRYPT_KEY_VALUE = "ENTER KEY HERE"
      private_constant :CRYPT_KEY_VALUE

      # Partitions with these IDs are historically marked with format=false
      # NOTE: "Dell Utility" was included here, but there is no such ID in the
      # new libstorage.
      NO_FORMAT_IDS = [PartitionId::PREP, PartitionId::DOS16]
      private_constant :NO_FORMAT_IDS

      # Partitions with these IDs are historically marked with create=false
      # NOTE: "Dell Utility" was the only entry here. See above.
      NO_CREATE_IDS = []
      private_constant :NO_CREATE_IDS

      def self.attributes
        [
          { name: :create },
          { name: :filesystem },
          { name: :format },
          { name: :label },
          { name: :uuid },
          { name: :lv_name },
          { name: :lvm_group },
          { name: :mount },
          { name: :mountby },
          { name: :partition_id },
          { name: :partition_nr },
          { name: :partition_type },
          { name: :subvolumes },
          { name: :size },
          { name: :crypt_fs },
          { name: :loop_fs },
          { name: :crypt_key }
        ]
      end

      define_attr_accessors

      # @!attribute create
      #   @return [Boolean] whether the partition must be created or exists

      # @!attribute crypt_fs
      #   @return [Boolean] whether the partition must be encrypted

      # @!attribute crypt_key
      #   @return [String] encryption key

      # @!attribute filesystem
      #   @return [Symbol] file system type to use in the partition, it also
      #     influences other fields
      #   @see #type_for_filesystem
      #   @see #id_for_partition

      # @!attribute partition_id
      #   @return [Fixnum] partition id. See #id_for_partition

      # @!attribute format
      #   @return [Boolean] whether the partition should be formatted

      # @!attribute label
      #   @return [String] label of the filesystem

      # @!attribute uuid
      #   @return [String] UUID of the partition

      # @!attribute lv_name
      #   @return [String] name of the LVM logical volume

      # @!attribute mount
      #   @return [String] mount point for the partition

      # @!attribute mountby
      #   @return [Symbol] :device, :label, :uuid, :path or :id

      # @!attribute partition_nr
      #   @return [Fixnum] the partition number of this partition

      # @!attribute partition_type
      #   @return [String] undocumented attribute that can only contain "primary"

      # @!attribute subvolumes
      #   @return [Array] list of subvolumes

      # @!attribute size
      #   @return [String] size of the partition in the flexible AutoYaST format

      # @!attribute loop_fs
      #   @return [Boolean] undocumented attribute

      def initialize
        @subvolumes = []
      end

      # Clones a device into an AutoYaST profile section by creating an instance
      # of this class from the information in a partition or LVM logical volume.
      #
      # @see PartitioningSection.new_from_storage for more details
      #
      # @param device [BlkDevice] a block device that can be cloned into a
      #   <partition> section, like a partition or an LVM logical volume.
      # @return [PartitionSection]
      def self.new_from_storage(device)
        result = new
        # So far, only real partitions are supported
        initialized = result.init_from_partition(device)
        initialized ? result : nil
      end

      # Filesystem type to be used for the real partition object, based on the
      # #filesystem value.
      #
      # @return [Filesystems::Type]
      def type_for_filesystem
        return nil unless filesystem
        Filesystems::Type.find(filesystem)
      end

      # Partition id to be used for the real partition object.
      #
      # This implements the AutoYaST documented logic. If #partition_id is
      # filled, the corresponding id is used. Otherwise SWAP or LINUX will be
      # used, depending on the value of #filesystem.
      #
      # @return [PartitionId]
      def id_for_partition
        return PartitionId.new_from_legacy(partition_id) if partition_id
        return PartitionId::SWAP if type_for_filesystem && type_for_filesystem.is?(:swap)
        PartitionId::LINUX
      end

      # Method used by {.new_from_storage} to populate the attributes when
      # cloning a partition device.
      #
      # As usual, it keeps the behavior of the old clone functionality, check
      # the implementation of this class for details.
      #
      # @param disk [Partition]
      def init_from_partition(partition)
        @create = !NO_CREATE_IDS.include?(partition.id)
        @partition_nr = partition.number
        @partition_type = "primary" if partition.type.is?(:primary)
        @partition_id = partition_id_from(partition)

        init_encryption_fields(partition)
        init_filesystem_fields(partition)

        # NOTE: The old AutoYaST exporter does not report the real size here.
        # It intentionally reports one cylinder less. Cylinders is an obsolete
        # unit (that equals to 8225280 bytes in my experiments).
        # According to the comments there, that was done due to bnc#415005 and
        # bnc#262535.
        @size = partition.size.to_i.to_s if create

        true
      end

    protected

      # Uses legacy ids for backwards compatibility. For example, BIOS Boot
      # partitions in the old libstorage were represented by the internal
      # code 259 and, thus, systems cloned with the old exporter
      # (AutoinstPartPlan) use 259 instead of the current 257.
      def partition_id_from(partition)
        id = enforce_bios_boot?(partition) ? PartitionId::BIOS_BOOT : partition.id
        id.to_i_legacy
      end

      def init_encryption_fields(partition)
        return unless partition.encrypted?

        @crypt_fs = true
        @loop_fs = true
        @crypt_key = CRYPT_KEY_VALUE
      end

      def init_filesystem_fields(partition)
        @format = false
        fs = partition.filesystem
        return unless fs

        @format = true unless NO_FORMAT_IDS.include?(partition.id)
        @filesystem = fs.type.to_sym
        @label = fs.label unless fs.label.empty?
        @mkfs_options = fs.mkfs_options unless fs.mkfs_options.empty?
        init_mount_options(fs)
      end

      # @param fs [Filesystem::BlkFilesystem]
      def init_mount_options(fs)
        @mount = fs.mountpoint if fs.mountpoint && !fs.mountpoint.empty?
        @mountby = fs.mount_by.to_sym
        @fstab_options = fs.fstab_options.join(",") unless fs.fstab_options.empty?
      end

      # Whether the given existing partition should be reported as GRUB (GPT
      # Bios Boot) in the cloned profile.
      #
      # @note To ensure backward compatibility, this method implements the
      # logic present in the old AutoYaST exporter that used to live in
      # AutoinstPartPlan#ReadHelper.
      # https://github.com/yast/yast-autoinstallation/blob/47c24fb98e074f5b6432f3a4f8b9421362ee29cc/src/modules/AutoinstPartPlan.rb#L345
      # Thus, this returns true for any partition with a Windows-related ID
      # that is configured to be mounted in /boot*
      # See commit 54e236cd428636b3bf8f92d2ac2914e5b1d67a90 of
      # yast-autoinstallation.
      #
      # @param partition [Partition]
      # @return [Boolean]
      def enforce_bios_boot?(partition)
        return false if partition.filesystem_mountpoint.nil?
        partition.id.is?(:windows_system) && partition.filesystem_mountpoint.include?("/boot")
      end
    end
  end
end
