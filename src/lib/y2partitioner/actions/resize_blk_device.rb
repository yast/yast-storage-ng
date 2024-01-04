# Copyright (c) [2017-2021] SUSE LLC
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
require "yast2/popup"
require "y2partitioner/dialogs/blk_device_resize"
require "y2partitioner/ui_state"
require "y2partitioner/dialogs/unmount"
require "y2partitioner/actions/base"
require "y2partitioner/actions/controllers/blk_device"

module Y2Partitioner
  module Actions
    # Action for resizing a partition or an LVM logical volume
    class ResizeBlkDevice < Base
      include Yast::Logger

      # Constructor
      #
      # @param device [Y2Storage::Partition, Y2Storage::LvmLv]
      def initialize(device)
        super()
        textdomain "storage"

        @device = device
        @controller = Controllers::BlkDevice.new(device)

        UIState.instance.select_row(device.sid)
      end

      private

      # @return [Y2Storage::Partition, Y2Storage::LvmLv] device to resize
      attr_reader :device

      # @return [Y2Partitioner::Actions::Controllers::BlkDevice] controller for a block device
      attr_reader :controller

      # Checks whether it is possible to resize the device
      #
      # It also warns the user before continue when
      #
      #   * the device seems to be empty (see #confirm_empty)
      #   * the device is an LVM thin snapshot (see #confirm_thin_snapshot_resize)
      #   * the device needs to be unmounted before resizing (i.e., NTFS), offering the option for
      #     unmounting it.
      #
      # @see Base#run?
      def run?
        return false unless confirm_empty
        return false unless unmount && validate
        return false unless confirm_thin_snapshot_resize

        true
      end

      # Runs the dialog to resize the device
      #
      # @see Base#perform_action
      #
      # @return [Symbol] :finish if the dialog returns :next; dialog result otherwise.
      def perform_action
        result = Dialogs::BlkDeviceResize.run(controller)

        (result == :next) ? :finish : result
      end

      # If the device seems to be empty the user has to confirm a warning stating
      # the high risk of data loss.
      #
      # @return [Boolean] true if there is no high risk or the user has accepted it
      def confirm_empty
        # If the device has descendants now resizing is ok even if
        # nothing was probed on the device since the user already made
        # an operation that overrides the device.
        return true if @device.descendants.any?

        # If the device does not exist in probed there cannot be an
        # undetected file system or storage system on it.
        return true if !@device.exists_in_probed?

        # If the device in the probed deviceraph has descendants
        # something was probed on it. Note: In the staging deviceraph
        # this something might have been removed so this check must
        # not be done on the staging deviceraph.
        probed = Y2Storage::StorageManager.instance.raw_probed
        return true if probed.find_device(@device.sid).descendants.any?

        message = _(
          "Neither a file system nor a storage system was detected on the\n" \
          "device. In case the device does contain a file system or a\n" \
          "storage system that is not supported by YaST, resizing will\n" \
          "most likely cause data loss. Really continue?"
        )

        Yast2::Popup.show(message, headline: :warning, buttons: :yes_no) == :yes
      end

      # Resizing a thin snapshot does not make too much sense. The user has to confirm a warning
      # before continue.
      #
      # @return [Boolean] true if device is not a thin snapshot or user decided go ahead
      def confirm_thin_snapshot_resize
        return true unless @device.is?(:lvm_thin_snapshot)

        message = _("Selected device is an LVM Thin Snapshot. Do you really want to resize it?")

        Yast2::Popup.show(message, headline: :warning, buttons: :yes_no) == :yes
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
      # A device is being used when it forms part of another device (e.g., LVM or MD RAID). The device
      # is not considered as used when it belongs to a multi-device filesystem (i.e., Btrfs).
      #
      # @return [String, nil] nil if the device is not being used.
      def used_device_error
        using_devs = device.component_of_names

        return nil if controller.multidevice_filesystem? || using_devs.none?

        format(
          # TRANSLATORS: %{name} is replaced by a device name (e.g., /dev/sda1) and %{users} is replaced
          # by a list of name devices (devices using the first one).
          _("The device %{name} is being used by:\n" \
            "%{users}\n\n" \
            "It cannot be resized.\n" \
            "To resize %{name}, make sure it is not used."),
          name: device.name, users: using_devs.join("\n")
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

      # Asks for unmounting the device, if required.
      #
      # NTFS tools require the filesystem to be unmounted.
      #
      # @return [Boolean] true if it is not required to unmount or the device was correctly
      #   unmounted; false when user cancels.
      def unmount
        return true unless mounted_ntfs?

        # TRANSLATORS: Note added to the dialog for trying to unmount a device
        note = _("It is not possible to check whether a NTFS\ncan be resized while it is mounted.")

        ntfs = controller.committed_filesystem
        Dialogs::Unmount.new(ntfs, note:, allow_continue: false).run == :finish
      end

      # Checks whether the current filesystem is NTFS, it exists on disk and it is mounted.
      #
      # @return [Boolean]
      def mounted_ntfs?
        controller.committed_current_filesystem? &&
          controller.mounted_committed_filesystem? &&
          controller.committed_filesystem.type.is?(:ntfs)
      end
    end
  end
end
