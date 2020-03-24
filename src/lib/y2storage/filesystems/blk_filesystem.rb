# Copyright (c) [2017-2019] SUSE LLC
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

require "yast/i18n"
require "y2storage/storage_class_wrapper"
require "y2storage/filesystems/base"

module Y2Storage
  module Filesystems
    # A local filesystem.
    #
    # This is a wrapper for Storage::BlkFilesystem
    class BlkFilesystem < Base
      include Yast::I18n

      wrap_class Storage::BlkFilesystem, downcast_to: ["Filesystems::Btrfs"]

      # @!method self.all(devicegraph)
      #   @param devicegraph [Devicegraph]
      #   @return [Array<Filesystems::BlkFilesystem>] all the block filesystems
      #     in the given devicegraph
      storage_class_forward :all, as: "Filesystems::BlkFilesystem"

      # @!method supports_label?
      #   @return [Boolean] whether the filesystem supports having a label
      storage_forward :supports_label?, to: :supports_label

      # @!method max_labelsize
      #   @return [Integer] max size of the label
      storage_forward :max_labelsize

      # @!attribute label
      #   @return [String] filesystem label
      storage_forward :label
      storage_forward :label=

      # @!method supports_uuid?
      #   @return [Boolean] whether the filesystem supports UUID
      storage_forward :supports_uuid?, to: :supports_uuid

      # @!attribute uuid
      #   @return [String] filesystem UUID
      storage_forward :uuid
      storage_forward :uuid=

      # @!method supports_shrink?
      #   @return [Boolean] whether the filesystem supports shrinking
      storage_forward :supports_shrink?, to: :supports_shrink

      # @!method supports_mounted_shrink?
      #   @return [Boolean] whether the filesystem supports shrinking while being mounted
      storage_forward :supports_mounted_shrink?, to: :supports_mounted_shrink

      # @!method supports_grow?
      #   @return [Boolean] whether the filesystem supports growing
      storage_forward :supports_grow?, to: :supports_grow

      # @!method supports_mounted_grow?
      #   @return [Boolean] whether the filesystem supports growing while being mounted
      storage_forward :supports_mounted_grow?, to: :supports_mounted_grow

      # @!attribute mkfs_options
      #   Options to use when calling mkfs during devicegraph commit (if the
      #   filesystem needs to be created in the system).
      #
      #   @return [String]
      storage_forward :mkfs_options
      storage_forward :mkfs_options=

      # @!attribute tune_options
      #   @return [String]
      storage_forward :tune_options
      storage_forward :tune_options=

      # @!method detect_content_info
      #   @return [Storage::ContentInfo]
      storage_forward :detect_content_info

      # @!method blk_devices
      #   Formatted block devices. It returns the block devices directly hosting
      #   the filesystem. That is, for encrypted filesystems it returns the
      #   encryption devices.
      #
      #   In most cases, this collection will contain just one element, since
      #   most filesystems sit on top of just one block device.
      #   But that's not necessarily true for Btrfs or for filesystems in which
      #   the journal or the metadata is stored in a separate device.
      #   For the Btrfs case, see
      #   https://btrfs.wiki.kernel.org/index.php/Using_Btrfs_with_Multiple_Devices
      #   For the extX case, see the journal options at mkfs.ext4 documentation.
      #
      #   @return [Array<BlkDevice>]
      storage_forward :blk_devices, as: "BlkDevice"

      # Raw (non encrypted) version of the formatted devices. If the filesystem
      # is not encrypted, it returns the same collection that #blk_devices,
      # otherwise it returns the original devices instead of the encryption
      # ones.
      #
      # @return [Array<BlkDevice>]
      def plain_blk_devices
        blk_devices.map(&:plain_device)
      end

      # Block device base name
      #
      # When the filesystem is single-device, this method simply returns the base name of the block
      # device (e.g., "sda1"). And for multi-device ones, it returns the first base name between brackets
      # and followed by horizontal ellipsis (e.g., "(sda1...)").
      #
      # @return [String]
      def blk_device_basename
        basename = plain_blk_devices.map(&:basename).min

        return basename unless multidevice?

        textdomain "storage"

        # TRANSLATORS: block device basename for a multi-device filesystem, where %{basename} is replaced
        # by the basename of the first block device (e.g., "(sda1...)").
        format(_("(%{basename}\u2026)"), basename: basename)
      end

      # Whether it is a multi-device filesystem
      #
      # So far, filesystems detected as multi-device are
      #
      #   - Btrfs, when built over several devices
      #   - Ext3/4, if the journal is placed in an external device
      #
      # @return [Boolean]
      def multidevice?
        blk_devices.size > 1
      end

      # Returns the device used to hold the journal
      #
      # Mainly useful for Ext3/4 filesystems with an external journal
      #
      # @return [BlkDevice, nil] nil if there is not a device used for the journal
      def journal_device
        blk_devices.find(&:journal?)
      end

      # Checks whether the filesystem has the capability of hosting Btrfs subvolumes
      #
      # It only should be true for Btrfs.
      def supports_btrfs_subvolumes?
        false
      end

      # @return [Boolean]
      def in_network?
        blk_devices.any?(&:in_network?)
      end

      # Option used in the fstab file for devices that require network
      NETWORK_OPTION = "_netdev".freeze
      private_constant :NETWORK_OPTION

      # @see Mountable#extra_default_mount_options
      #
      # @return [Array<String>]
      def extra_default_mount_options
        # Adding _netdev is implemented in BlkFilesystem so far.
        #  - Fully network-based filesystems like NFS do not need it because systemd
        #    always detect those right, without the need of _netdev.
        #  - We don't specify extra options for Btrfs subvolumes because the current
        #    libstorage-ng implementation would ignore them (BtrfsSubvolume#mount_options
        #    is bypassed to only return subvol=$path).
        if in_network?
          (super + [NETWORK_OPTION]).uniq
        else
          super
        end
      end

      # @see Base#stable_name?
      def stable_name?
        blk_devices.all?(&:stable_name?)
      end

      # @see Base#encrypted?
      def encrypted?
        plain_blk_devices.any?(&:encrypted?)
      end

      # @see Base#encrypted?
      def volatile?
        blk_dev = blk_devices.first
        return false unless blk_dev.is?(:encryption)

        enc_method = blk_dev.method
        return false unless enc_method

        enc_method.only_for_swap?
      end

      # Checks if this filesystem type supports any kind of resize at all,
      # either shrinking or growing.
      #
      # @return [Boolean]
      def supports_resize?
        supports_shrink? || supports_grow?
      end

      # @see Filesystems::Base#match_fstab_spec?
      def match_fstab_spec?(spec)
        if /^UUID=(.*)/ =~ spec
          return !Regexp.last_match(1).empty? && uuid == Regexp.last_match(1)
        end

        if /^LABEL=(.*)/ =~ spec
          return !Regexp.last_match(1).empty? && label == Regexp.last_match(1)
        end

        blk_devices.any? do |dev|
          dev.name == spec || dev.udev_full_all.include?(spec)
        end
      end

      # Whether it makes sense modify the attribute about snapper configuration
      #
      # @see Y2Storage::Filesystems::Btrfs.configure_snapper
      #
      # @return [Boolean]
      def can_configure_snapper?
        root? && respond_to?(:configure_snapper=)
      end

      # Volume specification that applies for this filesystem
      #
      # @see Y2Storage::VolumeSpecification.for
      #
      # @return [Y2Storage::VolumeSpecification, nil] nil if no specification
      #   matches the filesystem
      def volume_specification
        return nil unless mount_point

        Y2Storage::VolumeSpecification.for(mount_point.path)
      end

      # Most suitable file path to reference the filesystem
      #
      # @see Mountable#preferred_mount_by
      #
      # @return [String]
      def preferred_name
        path_for_mount_by(preferred_mount_by)
      end

      # File path to reference the filesystem based on the current mount by option
      #
      # @see #mount_by
      #
      # @return [String, nil] nil if the name cannot be determined for the current mount by option
      def mount_by_name
        return nil unless mount_by

        path_for_mount_by(mount_by)
      end

      # Name (full path) that can be used to reference the filesystem for the given mount by option
      #
      # @return [String, nil] nil if the name cannot be determined for the given mount by option
      def path_for_mount_by(mount_by)
        if mount_by.is?(:label, :uuid)
          attr_value = public_send(mount_by.to_sym)
          mount_by.udev_name(attr_value)
        else
          blk_devices.first.path_for_mount_by(mount_by)
        end
      end

      protected

      # @see Device#is?
      def types_for_is
        super << :blk_filesystem
      end
    end
  end
end
