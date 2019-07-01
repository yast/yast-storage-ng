# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/widgets/configurable_blk_devices_table"

module Y2Partitioner
  module Widgets
    # Table for BTRFS filesystems
    class BtrfsFilesystemsTable < ConfigurableBlkDevicesTable
      # Constructor
      #
      # @param filesystems [Array<Y2Storage::Filesystems::Btrfs>]
      # @param pager [CWM::Pager]
      # @param buttons_set [DeviceButtonsSet]
      def initialize(filesystems, pager, buttons_set = nil)
        textdomain "storage"

        super
        show_columns(*fs_columns)
      end

      private

      # Table columns
      #
      # @return [Array<Symbol>]
      def fs_columns
        [:btrfs_id, :mount_point, :label, :btrfs_devices, :uuid]
      end

      # Column label
      #
      # @return [String]
      def btrfs_id_title
        # TRANSLATORS: label of a table column
        _("Id")
      end

      # Column label
      #
      # @return [String]
      def label_title
        # TRANSLATORS: label of a table column
        _("Label")
      end

      # Column label
      #
      # @return [String]
      def btrfs_devices_title
        # TRANSLATORS: label of a table column
        _("Devices")
      end

      # Column label
      #
      # @return [String]
      def uuid_title
        # TRANSLATORS: label of a table column
        _("UUID")
      end

      # Column value
      #
      # @param filesystem [Y2Storage::Filesystems::Btrfs]
      # @return [String] e.g., "sda1" or "(sda1...)"
      def btrfs_id_value(filesystem)
        filesystem.blk_device_basename
      end

      # Column value
      #
      # @param filesystem [Y2Storage::Filesystems::Btrfs]
      # @return [String] e.g., "data"
      def label_value(filesystem)
        filesystem.label
      end

      # Column value
      #
      # BTRFS devices names
      #
      # @param filesystem [Y2Storage::Filesystems::Btrfs]
      # @return [String] e.g., "/dev/sda1, /dev/sda2"
      def btrfs_devices_value(filesystem)
        filesystem.plain_blk_devices.map(&:name).sort.join(", ")
      end

      # Column value
      #
      # @param filesystem [Y2Storage::Filesystems::Btrfs]
      # @return [String] e.g., "111222333-444-55"
      def uuid_value(filesystem)
        filesystem.uuid
      end
    end
  end
end
