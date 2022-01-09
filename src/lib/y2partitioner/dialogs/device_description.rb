# Copyright (c) [2020] SUSE LLC
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

require "y2partitioner/dialogs/popup"
require "y2partitioner/widgets/disk_device_description"
require "y2partitioner/widgets/md_description"
require "y2partitioner/widgets/partition_description"
require "y2partitioner/widgets/filesystem_description"
require "y2partitioner/widgets/lvm_vg_description"
require "y2partitioner/widgets/lvm_lv_description"
require "y2partitioner/widgets/bcache_description"
require "y2partitioner/widgets/stray_blk_device_description"
require "y2partitioner/widgets/btrfs_subvolume_description"

module Y2Partitioner
  module Dialogs
    # Pop-up dialog to display the details of a given device
    class DeviceDescription < Popup
      extend Yast::I18n

      # @return [Y2Storage::Device]
      attr_accessor :device

      # Constructor
      def initialize(device)
        super()
        textdomain "storage"
        @device = device
      end

      # Possible page titles, based on the type of device
      TITLES = {
        # TRANSLATORS: Heading. String followed by a device name like /dev/bcache0
        bcache:          N_("Bcache: %s"),
        # TRANSLATORS: Heading. String followed by device name of hard disk
        disk_device:     N_("Hard Disk: %s"),
        # TRANSLATORS: Heading. String followed by name of a file system
        filesystem:      N_("File System: %s"),
        # TRANSLATORS: Heading. String followed by name of an LVM logical volume
        lvm_lv:          N_("Logical Volume: %s"),
        # TRANSLATORS: Heading. String followed by name of an LVM volume group
        lvm_vg:          N_("Volume Group: %s"),
        # TRANSLATORS: Heading. String followed by name of a software RAID
        software_raid:   N_("RAID: %s"),
        # TRANSLATORS: Heading. String followed by the name of a partition
        partition:       N_("Partition: %s"),
        # TRANSLATORS: Heading. String followed by name of a Btrfs subvolume
        btrfs_subvolume: N_("Btrfs Subvolume: %s")
      }
      private_constant :TITLES

      # Widget classes that can be used to display information of a device
      WIDGETS = {
        disk_device:      Widgets::DiskDeviceDescription,
        disk:             Widgets::DiskDeviceDescription,
        blk_filesystem:   Widgets::FilesystemDescription,
        software_raid:    Widgets::MdDescription,
        partition:        Widgets::PartitionDescription,
        lvm_vg:           Widgets::LvmVgDescription,
        lvm_lv:           Widgets::LvmLvDescription,
        bcache:           Widgets::BcacheDescription,
        stray_blk_device: Widgets::StrayBlkDeviceDescription,
        btrfs_subvolume:  Widgets::BtrfsSubvolumeDescription,
        tmpfs:            Widgets::FilesystemDescription
      }
      private_constant :WIDGETS

      # Main method to execute a dialog
      #
      # Overriden to make sure we don't open a dialog if we have no widget to
      # display
      def run
        return nil unless info_widget

        super
      end

      # Title of the dialog
      #
      # @return [String]
      def title
        entry = TITLES.find { |k, _v| device.is?(k) }
        # TRANSLATORS: Heading for a generic storage device
        # TRANSLATORS: String followed by name of the storage device
        title = entry ? entry.last : N_("Device: %s")

        format(_(title), name)
      end

      # Contents of the dialog
      #
      # @return [Yast::Term]
      def contents
        @contents ||= VBox(info_widget)
      end

      private

      # Device name used for the title of the dialog
      #
      # @return [String]
      def name
        return device.path if device.is?(:btrfs_subvolume)

        device.name
      end

      # Widget displaying the information about the device
      def info_widget
        return @info_widget if @info_widget

        entry = WIDGETS.find { |k, _v| device.is?(k) }
        @info_widget = entry ? entry.last.new(device) : nil
      end

      # @see Y2Partitioner::Dialogs::Popup
      def buttons
        [ok_button]
      end

      # @see Y2Partitioner::Dialogs::Popup
      def min_width
        70
      end
    end
  end
end
