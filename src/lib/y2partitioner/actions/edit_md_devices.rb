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
require "y2partitioner/actions/transaction_wizard"
require "y2partitioner/actions/controllers/md"
require "y2partitioner/dialogs/md_edit_devices"
require "y2partitioner/device_graphs"

Yast.import "Popup"

module Y2Partitioner
  module Actions
    # Action for editing the devices of a Software RAID
    class EditMdDevices < TransactionWizard
      # Constructor
      #
      # @param md [Y2Storage::Md]
      def initialize(md)
        super()
        textdomain "storage"

        @device_sid = md.sid
      end

      # Calls the dialog for editing the devices
      #
      # @return [Symbol] :finish if the dialog returns :next; dialog result otherwise.
      def resize
        result = Dialogs::MdEditDevices.run(controller)
        result == :next ? :finish : result
      end

    protected

      # @return [Controllers::Md]
      attr_reader :controller

      # @see TransactionWizard
      def init_transaction
        # The controller object must be created within the transaction
        @controller = Controllers::Md.new(md: device)
      end

      # @see TransactionWizard
      def sequence_hash
        {
          "ws_start" => "resize",
          "resize"   => { finish: :finish }
        }
      end

      # @see TransactionWizard
      def run?
        not_committed_validation && not_used_validation
      end

      # Checks whether the MD RAID does not exist on disk (see {#committed?})
      #
      # @note An error popup is shown when the MD RAID exists on disk.
      #
      # @return [Boolean] true if the device is not committed; false otherwise.
      def not_committed_validation
        return true unless committed?

        Yast::Popup.Error(
          # TRANSLATORS: error popup, %{name} is replaced by device name (e.g., /dev/md1)
          format(
            _("The RAID %{name} is already created on disk and its used devices\n" \
              "cannot be modified. To modify the used devices, remove the RAID\n" \
              "and create it again."),
            name: controller.md.name
          )
        )

        false
      end

      # Checks whether the MD RAID is not used as LVM physical volume (see {#used?})
      #
      # @note An error popup is shown when the MD RAID belongs to a volume group.
      #
      # @return [Boolean] true if the device does not belong to a volume group;
      #   false otherwise.
      def not_used_validation
        return true unless used?

        Yast::Popup.Error(
          # TRANSLATORS: error popup, %{name} is replaced by device name (e.g., /dev/md1)
          format(
            _("The RAID %{name} is in use. It cannot be\n" \
              "resized. To resize %{name}, make sure it is not used."),
            name: controller.md.name
          )
        )

        false
      end

      # @return [Boolean] true if the MD RAID is already created on disk; false otherwise
      def committed?
        system = Y2Partitioner::DeviceGraphs.instance.system
        controller.md.exists_in_devicegraph?(system)
      end

      # @return [Boolean] true if the MD RAID belongs to a volume group; false otherwise
      def used?
        controller.md.descendants.any? { |d| d.is?(:lvm_vg) }
      end
    end
  end
end
