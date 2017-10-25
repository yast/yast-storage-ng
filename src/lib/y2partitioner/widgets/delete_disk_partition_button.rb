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
require "cwm"
require "y2partitioner/ui_state"

Yast.import "Popup"
Yast.import "HTML"

module Y2Partitioner
  module Widgets
    # Button for deleting a disk device or partition
    class DeleteDiskPartitionButton < CWM::PushButton
      # Constructor
      # @param device [Y2Storage::BlkDevice]
      # @param table [Y2Partitioner::Widgets::BlkDevicesTable]
      # @param device_graph [Y2Storage::Devicegraph]
      def initialize(device: nil, table: nil, device_graph: nil)
        textdomain "storage"

        unless device || (table && device_graph)
          raise ArgumentError, "At least device or combination of table and device_graph have to be set"
        end

        @device = device
        @table = table
        @device_graph = device_graph
      end

      # @macro seeAbstractWidget
      def label
        _("Delete...")
      end

      # Checks whether delete action can be performed and if so,
      # a confirmation popup is shown.
      #
      # @note Delete action is carried out only if user confirms.
      def handle
        return nil unless delete_validations
        return nil unless confirm(device)

        delete_device(device)
        :redraw
      end

    private

      # Current device to delete
      #
      # @return [Y2Storage::BlkDevice]
      def device
        @device || @table.selected_device
      end

      # Checks whether the device can be deleted
      #
      # @note Some popups could be shown when it is not possible
      #   to delete the device.
      #
      # @return [Boolean] {true} if it is possible to delete the device;
      #   {false} otherwise.
      def delete_validations
        presence_validation && not_empty_partitions_validation
      end

      # Checks whether there is a device to delete
      #
      # @note An error popup is shown when there is no device.
      #
      # @return [Boolean]
      def presence_validation
        return true unless device.nil?

        Yast::Popup.Error(_("No device selected"))
        false
      end

      # Checks whether a partitionable has any partition for deleting
      #
      # @note An error popup is shown when there is no partition.
      #
      # @return [Boolean]
      def not_empty_partitions_validation
        return true unless device.is?(:partitionable)

        partition_table = device.partition_table
        if partition_table.nil? || partition_table.partitions.empty?
          Yast::Popup.Error(_("There are no partitions to delete on this disk"))
          return false
        end

        true
      end

      # Deletes the indicated device
      #
      # @note When the device is a partitionable, all its partitions are deleted.
      #
      # @note Shadowing for BtrFS subvolumes is always refreshed.
      # @see Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing
      #
      # @param device [Y2Storage::BlkDevice]
      def delete_device(device)
        if device.is?(:partitionable)
          log.info "deleting partitions for #{device}"
          device.partition_table.delete_all_partitions unless device.partition_table.nil?
          UIState.instance.select_row(device)
        else
          log.info "deleting partition #{device}"
          partitionable = device.partitionable
          partitionable.partition_table.delete_partition(device)
          UIState.instance.select_row(partitionable)
        end

        device_graph = DeviceGraphs.instance.current
        Y2Storage::Filesystems::Btrfs.refresh_subvolumes_shadowing(device_graph)
      end

      def confirm(device)
        names = children_names(device)

        if names.empty?
          Yast::Popup.YesNo(
            # TRANSLATORS %s is device to be deleted
            format(_("Really delete %s?"), device.name)
          )
        else
          confirm_recursive_delete(
            names,
            _("Confirm Deleting of All Partitions"),
            # TRANSLATORS: type stands for type of device and name is its identifier
            format(_("The %{type} \"%{name}\" contains at least one another device.\n" \
              "If you proceed, the following devices will be deleted:"),
              name: device.name,
              type: device.is?(:disk) ? _("disk") : _("partition")),
            format(_("Really delete all devices on \"%s\"?"), device.name)
          )
        end
      end

      def children_names(device)
        device.descendants.map do |dev|
          dev.name if dev.respond_to?(:name)
        end.compact
      end

      # @param rich_text [String]
      # @return [Boolean]
      def fancy_question(headline, label_before, rich_text, label_after, button_term)
        display_info = Yast::UI.GetDisplayInfo || {}
        has_image_support = display_info["HasImageSupport"]

        layout = VBox(
          VSpacing(0.4),
          HBox(
            has_image_support ? Top(Image(Yast::Icon.IconPath("question"))) : Empty(),
            HSpacing(1),
            VBox(
              Left(Heading(headline)),
              VSpacing(0.2),
              Left(Label(label_before)),
              VSpacing(0.2),
              Left(RichText(rich_text)),
              VSpacing(0.2),
              Left(Label(label_after)),
              button_term
            )
          )
        )

        Yast::UI.OpenDialog(layout)
        ret = Yast::UI.UserInput
        Yast::UI.CloseDialog

        ret == :yes
      end

      # TODO: copy and pasted code from old storage, feel free to improve
      def confirm_recursive_delete(devices, headline, label_before, label_after)
        button_box = ButtonBox(
          PushButton(Id(:yes), Opt(:okButton), Yast::Label.DeleteButton),
          PushButton(
            Id(:no_button),
            Opt(:default, :cancelButton),
            Yast::Label.CancelButton
          )
        )

        fancy_question(headline,
          label_before,
          Yast::HTML.List(devices.sort),
          label_after,
          button_box)
      end
    end
  end
end
