# Copyright (c) [2018-2020] SUSE LLC
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
require "cwm/widget"
require "y2partitioner/widgets/lvm_lv_add_button"
require "y2partitioner/widgets/partition_add_button"
require "y2partitioner/widgets/device_delete_button"
require "y2partitioner/widgets/btrfs_modify_button"
require "y2partitioner/widgets/blk_device_edit_button"
require "y2partitioner/widgets/partition_table_add_button"

module Y2Partitioner
  module Widgets
    # Widget containing the set of buttons that is displayed for each device at
    # the bottom of a table of devices. Initially it displays an empty
    # widget. Every time the widget is (re)targeted to a new device (see
    # {#device=}) the content will be replaced by the appropiate set of buttons
    # for that device.
    class DeviceButtonsSet < CWM::ReplacePoint
      # List of supported device types
      #
      # Each entry represents a symbol to be passed to Device#is?, it that call
      # returns true, the appropiate set of buttons is returned
      #
      # @return [Array<Symbol>]
      SUPPORTED_TYPES = [
        :partition, :software_raid, :lvm_vg, :lvm_lv, :stray_blk_device, :bcache, :disk_device, :btrfs
      ]
      private_constant :SUPPORTED_TYPES

      # @return [Y2Storage::Device] current target for the actions
      attr_reader :device

      # @return [CWM::AbstractWidget] set of buttons displayed
      attr_reader :buttons

      # Constructor
      #
      # @param pager [CWM::TreePager] see {#pager}
      def initialize(pager)
        @device = nil
        @buttons = []
        @pager = pager
        super(id: "device_buttons_set", widget: empty_widget)
      end

      # Sets the target device
      #
      # As a consequence, the displayed buttons are recalculated and redrawn
      # to reflect the new device.
      #
      # @param dev [Y2Storage::Device] new target
      def device=(dev)
        @device = dev
        @buttons = calculate_buttons
        refresh
      end

      private

      # @return [CWM::TreePager] general pager used to navigate through the
      #   partitioner
      attr_reader :pager

      # Redraws the widget
      def refresh
        if buttons.empty?
          replace(empty_widget)
        else
          replace(ButtonsBox.new(buttons))
        end
      end

      # List of buttons that make sense for the current target device
      def calculate_buttons
        return [] if device.nil?

        SUPPORTED_TYPES.each do |type|
          return send(:"#{type}_buttons") if device.is?(type)
        end

        # Returns no buttons if the device is not supported
        []
      end

      # Just an empty widget to display in case there are no buttons to display
      def empty_widget
        @empty_widget ||= CWM::Empty.new("device_buttons_set_empty")
      end

      # Buttons to display if {#device} is a partition
      def partition_buttons
        [
          BlkDeviceEditButton.new(device: device),
          PartitionAddButton.new(device: device),
          DeviceDeleteButton.new(pager: pager, device: device)
        ]
      end

      # Buttons to display if {#device} is a software raid
      def software_raid_buttons
        [
          BlkDeviceEditButton.new(device: device),
          PartitionAddButton.new(device: device),
          DeviceDeleteButton.new(pager: pager, device: device)
        ]
      end

      # Buttons to display if {#device} is a bcache device
      def bcache_buttons
        [
          BlkDeviceEditButton.new(device: device),
          PartitionAddButton.new(device: device),
          DeviceDeleteButton.new(pager: pager, device: device)
        ]
      end

      # Buttons to display if {#device} is a disk device
      def disk_device_buttons
        [
          modify_disk_button,
          PartitionAddButton.new(device: device)
        ]
      end

      # Buttons to display if {#device} is a Xen virtual partition
      # (StrayBlkDevice)
      def stray_blk_device_buttons
        [BlkDeviceEditButton.new(device: device)]
      end

      # Buttons to display if {#device} is a volume group
      def lvm_vg_buttons
        [
          LvmLvAddButton.new(device: device),
          DeviceDeleteButton.new(pager: pager, device: device)
        ]
      end

      # Buttons to display if {#device} is a logical volume
      def lvm_lv_buttons
        [
          BlkDeviceEditButton.new(device: device),
          LvmLvAddButton.new(device: device),
          DeviceDeleteButton.new(pager: pager, device: device)
        ]
      end

      # Buttons to display if {#device} is a BTRFS filesystem
      def btrfs_buttons
        [
          BtrfsModifyButton.new(device: device),
          DeviceDeleteButton.new(pager: pager, device: device)
        ]
      end

      # Button to modify a disk device
      #
      # Note that some block devices cannot be edited because they cannot be used as block devices,
      # (e.g., DASD devices).
      #
      # @return [CWM::AbstractWidget]
      def modify_disk_button
        return BlkDeviceEditButton.new(device: device) if device.usable_as_blk_device?

        PartitionTableAddButton.new(device: device)
      end

      # Simple widget to represent an HBox with a CWM API
      class ButtonsBox < CWM::CustomWidget
        # Constructor
        #
        # @param buttons [Array<CWM::AbstractWidget>] set of buttons to enclose
        #   in the horizontal box
        def initialize(buttons)
          @buttons = buttons
        end

        # @macro seeCustomWidget
        def contents
          HBox(*@buttons)
        end
      end
    end
  end
end
