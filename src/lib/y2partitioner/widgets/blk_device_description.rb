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

require "y2partitioner/widgets/device_description"
require "y2partitioner/widgets/blk_device_attributes"

module Y2Partitioner
  module Widgets
    # Richtext filled with the description of a block device
    #
    # The block device is given during initialization (see {DeviceDescription}).
    class BlkDeviceDescription < DeviceDescription
      alias_method :blk_device, :device

      include BlkDeviceAttributes

      # @see #blk_device_description
      # @see #filesystem_description
      #
      # @return [String]
      def device_description
        blk_device_description + filesystem_description
      end

      # Richtext description of a block device
      #
      # A block device description is composed by the header "Device" and
      # a list of attributes
      #
      # @return [String]
      def blk_device_description
        # TRANSLATORS: heading for the section about a block device
        output = Yast::HTML.Heading(_("Device:"))
        output << Yast::HTML.List(blk_device_attributes)
      end

      # Attributes for describing a block device
      #
      # @return [Array<String>]
      def blk_device_attributes
        [
          device_name,
          device_size,
          device_encrypted,
          device_udev_by_path.join(Yast::HTML.Newline),
          device_udev_by_id.join(Yast::HTML.Newline)
        ]
      end

      # Richtext description of the filesystem on a block device
      #
      # The filesystem description is composed by the header "File System" and
      # a list of attributes
      #
      # @return [String]
      def filesystem_description
        # TRANSLATORS: heading for the section about a filesystem on a block device
        Yast::HTML.Heading(_("File System:")) +
          Yast::HTML.List(filesystem_attributes)
      end

      # Attributes for describing a filesystem
      #
      # @return [Array<String>]
      def filesystem_attributes
        [
          device_filesystem,
          device_filesystem_mount_point,
          device_filesystem_label
        ]
      end

      # Fields to show in help
      #
      # FIXME: help fields and attributes for the description are directly related. They
      # could be unified to declare them only once.
      #
      # @return [Array<Symbol>]
      def help_fields
        blk_device_help_fields + filesystem_help_fields
      end

      BLK_DEVICE_HELP_FIELDS = [:device, :size, :encrypted, :udev_path, :udev_id].freeze

      # Help fields for a block device
      #
      # @return [Array<Symbol>]
      def blk_device_help_fields
        BLK_DEVICE_HELP_FIELDS.dup
      end

      FILESYSTEM_HELP_FIELDS = [:fs_type, :mount_point, :label].freeze

      # Help fields for a filesystem
      #
      # @return [Array<Symbol>]
      def filesystem_help_fields
        FILESYSTEM_HELP_FIELDS.dup
      end
    end
  end
end
