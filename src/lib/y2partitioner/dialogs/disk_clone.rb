# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/dialogs/popup"
require "y2partitioner/device_graphs"
require "y2partitioner/confirm_recursive_delete"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Dialog for cloning a device
    class DiskClone < Popup
      # @return [Actions::Controllers::DiskDevice]
      attr_reader :controller

      # Constructor
      #
      # @param controller [Actions::Controllers::DiskDevice]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      # @macro seeDialog
      def title
        # TRANSLATORS: %{name} is replaced by a disk device name (e.g., /dev/sda)
        format(_("Clone partition layout of %{name}"), name: controller.device.name)
      end

      # @macro seeDialog
      # @see DevicesSelector
      def contents
        @contents ||= VBox(DevicesSelector.new(controller))
      end

      # Widget to select devices for cloning
      class DevicesSelector < CWM::MultiSelectionBox
        include ConfirmRecursiveDelete

        # Constructor
        #
        # @param controller [Actions::Controllers::DiskDevice]
        def initialize(controller)
          textdomain "storage"

          @controller = controller
          self.handle_all_events = true
        end

        # @return [String]
        def label
          _("Available target disks:")
        end

        # @return [Array<Integer, String>]
        def items
          controller.suitable_devices_for_cloning.map { |d| [d.sid, label_for(d)] }
        end

        # Checks whether any device was selected
        #
        # @note A confirmation popup is shown when deleting devices is needed
        #   for cloning into the selected devices.
        #
        # @return [Boolean]
        def validate
          return confirm? if selected_devices?

          Yast::Popup.Error(_("Select a target disk for creating a clone"))
          false
        end

        # Saves the selected devices into the controller
        def store
          controller.selected_devices_for_cloning = selected_devices
        end

        # FIXME: The help handle does not work without a wizard
        #
        # This handle should belongs to the dialog
        def handle(event)
          return nil if event["ID"] != :help

          Yast::Wizard.ShowHelp(help)
          nil
        end

        # Help text
        #
        # @return [String]
        def help
          text1 = _("Select one or more (if available) hard disks that will have the same partition " \
                    "layout as this disk")
          text2 = _("Disks marked with the sign '*' contain one or more partitions. After cloning, " \
                    "these partitions will be deleted")

          "<p>#{text1}</p><p>#{text2}</p>"
        end

      private

        # @return [Actions::Controllers::DiskDevice]
        attr_reader :controller

        # Current devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def working_graph
          DeviceGraphs.instance.current
        end

        # Current disk device
        #
        # @return [Y2Storage::BlkDevice]
        def device
          controller.device
        end

        # Whether there is any selected device
        #
        # @return [Boolean]
        def selected_devices?
          !selected_devices.empty?
        end

        # All selected devices
        #
        # @return [Array<Y2Storage::Partitionable>]
        def selected_devices
          value.map { |d| working_graph.find_device(d) }
        end

        # Label to show for each available device
        #
        # @note Devices with partitions are marked with '*'.
        #
        # @return [String]
        def label_for(device)
          label = device.name
          label.concat("*") unless device.partitions.empty?
          label.concat(" (#{device.size.to_human_string})")
          label
        end

        # Whether deleting partitions is required to perform the cloning over the
        # selected devices
        #
        # @return [Boolean]
        def require_delete_partitions?
          selected_devices.any? { |d| !d.partitions.empty? }
        end

        # Asks whether to remove devices holded by the selected devices
        #
        # @see ConfirmRecursiveDelete
        #
        # @return [Boolean]
        def confirm?
          return true unless require_delete_partitions?

          confirm_recursive_delete(
            selected_devices,
            _("Confirm deleting"),
            _("The following devices will be deleted\nand all data on them will be lost:"),
            _("Really delete these devices?")
          )
        end
      end
    end
  end
end
