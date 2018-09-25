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
require "yast2/popup"
require "y2partitioner/device_graphs"
require "y2partitioner/confirm_recursive_delete"
require "y2partitioner/immediate_unmount"
require "y2partitioner/actions/controllers/blk_device"
require "y2storage/filesystems/btrfs"
require "abstract_method"

module Y2Partitioner
  module Actions
    # Base class for the action to delete a device
    class DeleteDevice
      include Yast::Logger
      include Yast::I18n
      include Yast::UIShortcuts
      include ConfirmRecursiveDelete
      include ImmediateUnmount

      # Constructor
      # @param device [Y2Storage::Device]
      def initialize(device)
        textdomain "storage"

        @device = device
      end

      # Checks whether delete action can be performed and if so, a confirmation popup is shown.
      # It only asks for unmounting the device it is currently mounted in the system.
      #
      # @note Delete action and refresh for shadowing of BtrFS subvolumes
      #   are only performed when user confirms.
      #
      # @see Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing
      #
      # @return [Symbol, nil]
      def run
        return :back unless validate && try_unmount && confirm
        delete
        Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(device_graph)

        :finish
      end

    private

      # @return [Y2Storage::Device] device to delete
      attr_reader :device

      # Current devicegraph
      #
      # @return [Y2Storage::Devicegraph]
      def device_graph
        DeviceGraphs.instance.current
      end

      # Deletes the indicated device
      #
      # @note Derived classes should implement this method.
      abstract_method :delete

      # Validations before performing the delete action
      #
      # @note The action can be performed is there are no errors (see #errors).
      #   Only the first error is shown.
      #
      # @return [Boolean]
      def validate
        current_errors = errors
        return true if current_errors.empty?

        Yast2::Popup.show(current_errors.first, headline: :error)
        false
      end

      # List of errors that avoid to delete the device
      #
      # @note Derived classes should overload this method.
      #
      # @return [Array<String>]
      def errors
        []
      end

      # Confirmation before performing the delete action
      #
      # @return [Boolean]
      def confirm
        # TRANSLATORS %s is the name of the device to be deleted (e.g., /dev/sda1)
        message = format(_("Really delete %s?"), device.name)

        result = Yast2::Popup.show(message, buttons: :yes_no)
        result == :yes
      end

      # Checks whether the device is used as physical volume
      #
      # @return [Boolean] true if device belongs to a volume group; false otherwise
      def used_by_lvm?
        !lvm_vg.nil?
      end

      # Volume group that the device belongs to
      #
      # @see Y2Storage::BlkDevice#lvm_pv
      #
      # @return [Y2Storage::LvmVg, nil] nil if the device does not belong to
      #   a volume group
      def lvm_vg
        return nil unless device.respond_to?(:lvm_pv)

        lvm_pv = device.lvm_pv
        lvm_pv ? lvm_pv.lvm_vg : nil
      end

      # Checks whether the device is used by a md raid
      #
      # @return [Boolean] true if device belongs to a md raid; false otherwise
      def used_by_md?
        !md.nil?
      end

      # Md Raid that the device belongs to
      #
      # @see Y2Storage::BlkDevice#md
      #
      # @return [Y2Storage::Md, nil] nil if the device does not belong to a md raid
      def md
        device.md
      end

      # Controller for a block device
      #
      # @return [Y2Partitioner::Actions::Controllers::BlkDevice, nil] nil when the device
      #   is not a block device.
      def controller
        return nil unless device.is?(:blk_device)

        @controller ||= Controllers::BlkDevice.new(device)
      end

      # Tries to unmount the device, if it is required.
      #
      # It asks the user for immediate unmount the device, see {#immediate_unmount}.
      #
      # @return [Boolean] true if it is not required to unmount or the device was correctly
      #   unmounted or the user decided to continue without unmounting; false when user cancels.
      def try_unmount
        return true unless need_try_unmount?

        # TRANSLATORS: Note added to the dialog for trying to unmount a device
        note = _("It cannot be deleted while mounted.")

        immediate_unmount(controller.committed_device, note: note)
      end

      # Whether it is necessary to try unmount (i.e., when deleting a mounted block device that
      # exists on the system)
      #
      # @return [Boolean]
      def need_try_unmount?
        return false unless device.is?(:blk_device)

        controller.mounted_committed_filesystem?
      end
    end
  end
end
