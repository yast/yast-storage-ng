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
require "y2partitioner/widgets/devices_selection"
require "y2partitioner/filesystem_errors"

module Y2Partitioner
  module Widgets
    # Widget making possible to add and remove partitions to a MD RAID
    class MdDevicesSelector < DevicesSelection
      include FilesystemErrors

      # Constructor
      #
      # @param controller [Y2Partitioner::Actions::Controllers::Md]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
        super()
      end

      def help
        help_available + help_selected
      end

      # @see Widgets::DevicesSelection#selected
      def selected
        controller.devices_in_md
      end

      # @see Widgets::DevicesSelection#selected_size
      def selected_size
        controller.md_size
      end

      # @see Widgets::DevicesSelection#unselected
      def unselected
        controller.available_devices
      end

      # @see Widgets::DevicesSelection#select
      def select(sids)
        find_devices(sids, unselected).each do |device|
          controller.add_device(device)
        end
      end

      # @see Widgets::DevicesSelection#select
      def unselect(sids)
        find_devices(sids, selected).each do |device|
          controller.remove_device(device)
        end
      end

      # @macro seeAbstractWidget
      # Whether the MD RAID is valid
      #
      # @note An error popup is shown when there are some errors in the
      #   MD RAID. A warning popup is shown if there are some warnings.
      #
      # @see #errors
      # @see #warnings
      #
      # @return [Boolean] true if there are no errors or the user
      #   decides to continue despite of the warnings; false otherwise.
      def validate
        current_errors = errors
        current_warnings = warnings

        return true if current_errors.empty? && current_warnings.empty?

        if current_errors.any?
          message = current_errors.join("\n\n")
          Yast2::Popup.show(message, headline: :error)
          false
        else
          message = current_warnings
          message << _("Do you want to continue with the current setup?")
          message = message.join("\n\n")
          Yast2::Popup.show(message, headline: :warning, buttons: :yes_no) == :yes
        end
      end

      # @macro seeAbstractWidget
      def handle(event)
        id = event["ID"]
        return super unless id

        case id.to_sym
        when :up
          controller.devices_one_step(sids_to_move, up: true)
          refresh
        when :top
          controller.devices_to_top(sids_to_move)
          refresh
        when :down
          controller.devices_one_step(sids_to_move, up: false)
          refresh
        when :bottom
          controller.devices_to_bottom(sids_to_move)
          refresh
        else
          super
        end

        nil
      end

      private

      # @return [Y2Partitioner::Actions::Controllers::Md]
      attr_reader :controller

      def help_available
        _("<p><b>Available Devices:</b> " \
          "Unused disks and partitions that can be used for a RAID. " \
          "A disk can be used if it does not contain any partitions " \
          "and no filesystem directly on the disk. " \
          "A partition can be used if it is not mounted. " \
          "It is recommended to use partition ID \"Linux RAID\" " \
          "for those partitions." \
          "</p>")
      end

      def help_selected
        _("<p><b>Selected Devices:</b> " \
          "The disks and partitions that are used for the RAID. " \
          "Different RAID levels have different requirements " \
          "for the minimum number of devices. " \
          "</p>")
      end

      # Errors detected in the MD RAID (e.g., it has not enough devices)
      #
      # @see #number_of_devices_error
      #
      # @return [Array<String>]
      def errors
        [number_of_devices_error].compact
      end

      # Error when the MD RAID does not contain the minumum number of devices
      # (according to the raid type).
      #
      # @return [String, nil] nil if the MD RAID contains at least the min number
      #   of required devices.
      def number_of_devices_error
        return nil if controller.devices_in_md.size >= controller.min_devices

        format(
          # TRANSLATORS: %{raid_level} is a RAID level (e.g., RAID10) and %{min} is a number
          _("For %{raid_level}, select at least %{min} devices."),
          raid_level: controller.md_level.to_human_string,
          min:        controller.min_devices
        )
      end

      # Warnings detected in the MD RAID
      #
      # @see FilesystemErrors
      #
      # @return [Array<String>]
      def warnings
        filesystem_errors(controller.md.filesystem)
      end

      # Content at the right of the two lists of devices, used to display the
      # ordering buttons.
      def right_area
        MarginBox(
          1,
          1,
          HSquash(
            VBox(*order_buttons)
          )
        )
      end

      # Identifiers of the devices that are marked by the user to be moved
      #
      # @return [Array<Integer>]
      def sids_to_move
        sids_for(@selected_table.value)
      end

      # Buttons to rearrange the devices in the MD
      def order_buttons
        [
          # TRANSLATORS: button to move an item to the first position of a sorted list
          PushButton(Id(:top), Opt(:hstretch), _("Top")),
          VSpacing(0.5),
          # TRANSLATORS: button to move an item one position up in a sorted list
          PushButton(Id(:up), Opt(:hstretch), _("Up")),
          VSpacing(0.5),
          # TRANSLATORS: button to move an item one position down in a sorted list
          PushButton(Id(:down), Opt(:hstretch), _("Down")),
          VSpacing(0.5),
          # TRANSLATORS: button to move an item to the last position of a sorted list
          PushButton(Id(:bottom), Opt(:hstretch), _("Bottom"))
        ]
      end

      def find_devices(sids, list)
        sids.map do |sid|
          list.find { |dev| dev.sid == sid }
        end.compact
      end
    end
  end
end
