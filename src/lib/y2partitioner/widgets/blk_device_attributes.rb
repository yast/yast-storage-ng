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

require "yast/i18n"

Yast.import "HTML"

module Y2Partitioner
  module Widgets
    # Shared helpers to display information about block device attributes
    #
    # Requirements:
    #   #blk_device [Y2Storage::BlkDevice] a block device instance.
    module BlkDeviceAttributes
      extend Yast::I18n

      # Sets textdomain
      def included(_target)
        textdomain "storage"
      end

      # Information about the kernel device name
      #
      # @return [String]
      def device_name
        # TRANSLATORS: Device name information, where %s is replaced by the
        # kernel path to device
        format(_("Device: %s"), blk_device.name)
      end

      # Information about the device size
      #
      # @return [String] device size in human readable format
      def device_size
        # TRANSLATORS: size information, where %s is replaced by a size (e.g., 10 GiB)
        format(_("Size: %s"), blk_device.size.to_human_string)
      end

      # Udev by path links for the device in human readable format
      #
      # @return [Array<String>]
      def device_udev_by_path
        paths = blk_device.udev_paths
        if paths.size > 1
          paths.each_with_index.map do |path, index|
            # TRANSLATORS: Device udev path information, where %i is replaced by an index number
            # and %s is replaced by the path where the device is connected on motherboard
            format(_("Device Path %i: %s"), index + 1, path)
          end
        else
          # TRANSLATORS: Device udev path information, where %s is replaced by the path where
          # the device is connected on motherboard
          [format(_("Device Path: %s"), paths.first)]
        end
      end

      # Udev by id links for the device in human readable format
      #
      # @return [Array<String>]
      def device_udev_by_id
        ids = blk_device.udev_ids
        if ids.size > 1
          ids.each_with_index.map do |id, index|
            # TRANSLATORS: Device udev id information, where %i is replaced by an index number
            # and %s is replaced by the udev ID for the device
            format(_("Device ID %i: %s"), index + 1, id)
          end
        else
          # TRANSLATORS: Device udev id information, where %s is replaced by the udev ID
          # for the device
          [format(_("Device ID: %s"), ids.first)]
        end
      end

      # Information about the device encryption
      #
      # @return [String]
      def device_encrypted
        # TRANSLATORS: Device encryption information, where %s is replaced by
        # 'Yes' when the device is encrypted or by 'No' otherwise
        format(_("Encrypted: %s"), blk_device.encrypted? ? _("Yes") : _("No"))
      end

      # Information about the device vendor
      #
      # @return [String]
      def device_vendor
        # TRANSLATORS: Device vendor information, where %s is replaced by a device vendor
        format(_("Vendor: %s"), blk_device.vendor || "")
      end

      # Information about the device model
      #
      # @return [String]
      def device_model
        # TRANSLATORS: Device model information, where %s is replaced by a device model
        format(_("Model: %s"), blk_device.model || "")
      end

      # Information about the device bus
      #
      # @return [String]
      def device_bus
        # TRANSLATORS: Device bus information, where %s is replaced by the computer bus
        # which the device is connected to (e.g., SATA or ATA)
        format(_("Bus: %s"), blk_device.bus || "")
      end

      # Information about number of sectors in the device
      #
      # @return [String]
      def device_sectors
        # TRANSLATORS: Number of sectors in the device, where %s is replaced by a number
        format(_("Number of Sectors: %i"), blk_device.region.length)
      end

      # Information about the device sector size
      #
      # @return [String]
      def device_sector_size
        # TRANSLATORS: Device sector size information, where %s is replaced by
        # a size (e.g., 1 MiB)
        format(_("Sector Size: %s"), blk_device.region.block_size.to_human_string)
      end

      # Information about the partition table type
      #
      # @return [String]
      def device_label
        ptable = blk_device.partition_table
        label = ptable.nil? ? "" : ptable.type.to_human_string

        # TRANSLATORS: partition table type information, where %s is replaced by
        # a partition table type (e.g., GPT, MS-DOS)
        format(_("Partition Table: %s"), label)
      end

      # Information about the filesystem type
      #
      # @return [String]
      def device_filesystem
        fs_type = blk_device.filesystem_type
        # TRANSLATORS: Filesystem type information, where %s is replaced by
        # a filesystem type (e.g., VFAT, BTRFS)
        format(_("File System: %s"), fs_type ? fs_type.to_human_string : "")
      end

      # Information about the mount point
      #
      # @return [String]
      def device_filesystem_mount_point
        # TRANSLATORS: Mount point information, where %s is replaced by a mount point
        format(_("Mount Point: %s"), blk_device.filesystem_mountpoint || "")
      end

      # Information about the filesystem label
      #
      # @return [String]
      def device_filesystem_label
        # TRANSLATORS: Filesystem label information, where %s is replaced by the
        # label associated to the filesystem
        format(_("Label: %s"), blk_device.filesystem_label || "")
      end
    end
  end
end
