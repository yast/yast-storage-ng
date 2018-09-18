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
require "yast2/popup"
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

      # Whether it is possible to edit the used devices for a MD RAID
      #
      # @note An error popup is shown when the devices cannot be edited: the MD RAID
      #   already exists on disk (see {#committed?}), the MD RAID belongs to a volume
      #   group (see {#used?}) or the MD RAID contains partitions (see {#partitioned?}).
      #
      # @see TransactionWizard
      #
      # @return [Boolean]
      def run?
        errors = [
          committed_error,
          used_error,
          partitioned_error
        ].compact

        return true unless errors.any?

        Yast2::Popup.show(errors.first, headline: :error)
        false
      end

      # Error the MD RAID exists on disk (see {#committed?})
      #
      # @return [String, nil] nil if the MD RAID does not exists on disk yet.
      def committed_error
        return nil unless committed?

        # TRANSLATORS: error message, %{name} is replaced by a device name (e.g., /dev/md1)
        format(
          _("The RAID %{name} is already created on disk and its used devices\n" \
            "cannot be modified. To modify the used devices, remove the RAID\n" \
            "and create it again."),
          name: controller.md.name
        )
      end

      # Error when the MD RAID is used as LVM physical volume (see {#used?})
      #
      # @return [String, nil] nil if the MD RAID is not in use.
      def used_error
        return nil unless used?

        # TRANSLATORS: error message, %{name} is replaced by a device name (e.g., /dev/md1)
        format(
          _("The RAID %{name} is in use. To modify the used devices,\n" \
            "make sure %{name} is not used."),
          name: controller.md.name
        )
      end

      # Error when the MD RAID contains partitions
      #
      # @return [String, nil] nil if the MD RAID has no partitions.
      def partitioned_error
        return nil unless partitioned?

        # TRANSLATORS: error message, %{name} is replaced by a device name (e.g., /dev/md1)
        format(
          _("The RAID %{name} is partitioned. To modify the used devices,\n" \
            "make sure %{name} has no partitions."),
          name: controller.md.name
        )
      end

      # Whether the MD RAID is already created on disk
      #
      # @return [Boolean]
      def committed?
        system = Y2Partitioner::DeviceGraphs.instance.system
        controller.md.exists_in_devicegraph?(system)
      end

      # Whether the MD RAID belongs to a volume group
      #
      # @return [Boolean]
      def used?
        controller.md.descendants.any? { |d| d.is?(:lvm_vg) }
      end

      # Whether the MD RAID contains partitions
      #
      # @return [Boolean]
      def partitioned?
        controller.md.partitions.any?
      end
    end
  end
end
