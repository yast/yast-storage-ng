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
require "yast/i18n"
require "y2partitioner/dialogs/blk_device_resize"
require "y2partitioner/ui_state"

Yast.import "Popup"

module Y2Partitioner
  module Actions
    # Action for resizing a partition
    class ResizeBlkDevice
      include Yast::I18n

      # Constructor
      #
      # @param device [Y2Storage::Partition]
      def initialize(device)
        textdomain "storage"

        @device = device
        UIState.instance.select_row(device)
      end

      # Checks whether it is possible to resize the device, and if so,
      # the action is performed.
      #
      # @note An error popup is shown when the device cannot be resized.
      #
      # @return [Symbol, nil]
      def run
        return :back unless validate
        resize
      end

    private

      # @return [Y2Storage::Partition] device to resize
      attr_reader :device

      # Resize information of the device to be resized
      #
      # @return [Y2Storage::ResizeInfo]
      def resize_info
        device.resize_info
      end

      # Runs the dialog to resize the device
      #
      # @return [Symbol] :finish if the dialog returns :next; dialog result otherwise.
      def resize
        result = Dialogs::BlkDeviceResize.run(device)

        result == :next ? :finish : result
      end

      # Checks whether the resize action can be performed
      #
      # @see Y2Storage::ResizeInfo#resize_ok?
      #
      # @return [Boolean] true if the resize action can be performed; false otherwise.
      def validate
        return true if resize_info.resize_ok?

        # TODO: Distinguish the reason why it is not possible to resize, for example:
        # * partition used by commited LVM or MD RAID
        # * extended partition with committed logical partitions

        Yast::Popup.Error(
          # TRANSLATORS: an error popup message
          _("This device cannot be resized.")
        )

        false
      end
    end
  end
end
