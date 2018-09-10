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
require "y2partitioner/immediate_unmount"
require "y2partitioner/actions/controllers/blk_device"

Yast.import "Popup"

module Y2Partitioner
  module Actions
    # Action for resizing a partition or an LVM logical volume
    class ResizeBlkDevice
      include Yast::Logger
      include Yast::I18n
      include ImmediateUnmount

      # Constructor
      #
      # @param device [Y2Storage::Partition, Y2Storage::LvmLv]
      def initialize(device)
        textdomain "storage"

        @device = device
        @controller = Controllers::BlkDevice.new(device)

        UIState.instance.select_row(device)
      end

      # Checks whether it is possible to resize the device, and if so, the action is performed.
      # It also checks whether the device needs to be unmounted before resizing (e.g., NTFS).
      # When unmounted device is required, it offers the option for unmounting it.
      #
      # @note An error popup is shown when the device cannot be resized.
      #
      # @return [Symbol, nil]
      def run
        return :back unless try_unmount && validate
        resize
      end

    private

      # @return [Y2Storage::Partition, Y2Storage::LvmLv] device to resize
      attr_reader :device

      # @return [Y2Partitioner::Actions::Controllers::BlkDevice] controller for a block device
      attr_reader :controller

      # Runs the dialog to resize the device
      #
      # @return [Symbol] :finish if the dialog returns :next; dialog result otherwise.
      def resize
        result = Dialogs::BlkDeviceResize.run(controller)

        result == :next ? :finish : result
      end

      # Checks whether the resize action can be performed
      #
      # @see Y2Storage::ResizeInfo#resize_ok?
      #
      # @return [Boolean] true if the resize action can be performed; false otherwise.
      def validate
        return true if errors.empty?

        # Only first error is shown
        Yast::Popup.Error(errors.first)
        false
      end

      # Errors when trying to resize a device
      #
      # @return [Array<Strings>]
      def errors
        [used_device_error,
         fstype_resize_support_error,
         cannot_be_resized_error].compact
      end

      # Error when trying to resize a used device
      #
      # @note A device is being used when it forms part of an LVM or MD RAID.
      #
      # @return [String, nil] nil if the device is not being used.
      def used_device_error
        return nil unless device.part_of_lvm_or_md?

        format(
          # TRANSLATORS: %{name} is replaced by a device name (e.g., /dev/sda1).
          _("The device %{name} is in use. It cannot be\n" \
            "resized. To resize %{name}, make sure it is not used."),
          name: device.name
        )
      end

      # Error when the filesystem type cannot be resized
      #
      # @return [String, nil] nil if the filesystem can be resized.
      def fstype_resize_support_error
        return nil unless device.formatted?
        return nil if device.blk_filesystem.supports_resize?

        _("This filesystem type cannot be resized.")
      end

      # Error when the device cannot be resized
      # This might be a multi-line message reporting more than one reason.
      #
      # @return [String, nil] nil if the device can be resized.
      def cannot_be_resized_error
        return nil if device.resize_info.resize_ok?

        log.warn("Can't resize #{device.name}: #{device.resize_info.reasons}")
        msg_lines = [_("This device cannot be resized:"), ""]
        msg_lines.concat(device.resize_info.reason_texts)
        msg_lines.join("\n")
      end

      # Tries to unmount the device, if it is required.
      #
      # It asks the user for immediate unmount the device, see {#immediate_unmount}.
      #
      # @return [Boolean] true if it is not required to unmount or the device was correctly
      #   unmounted; false when user cancels.
      def try_unmount
        return true unless need_try_unmount?

        # TRANSLATORS: Note added to the dialog for trying to unmount a device
        note = _("It is not possible to check whether a NTFS\ncan be resized while it is mounted.")

        immediate_unmount(controller.committed_device, note: note, allow_continue: false)
      end

      # Whether it is necessary to try unmount
      #
      # Unmount is needed when the current filesystem is NTFS, it exists on disk and it is mounted.
      # NTFS tools require the filesystem be unmounted.
      #
      # @return [Boolean]
      def need_try_unmount?
        controller.committed_current_filesystem? &&
          controller.mounted_committed_filesystem? &&
          controller.committed_filesystem.type.is?(:ntfs)
      end
    end
  end
end
