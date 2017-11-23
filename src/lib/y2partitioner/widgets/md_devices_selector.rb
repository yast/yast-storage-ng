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
require "y2partitioner/widgets/devices_selection"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Widget making possible to add and remove partitions to a MD RAID
    class MdDevicesSelector < DevicesSelection
      def initialize(controller)
        @controller = controller
        super()
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

      # Validates the number of devices.
      #
      # In fact, the devices are added and removed immediately as soon as
      # the user interacts with the widget, so this validation is only used to
      # prevent the user from reaching the next step in the wizard if the MD
      # array is not valid, not to prevent the information to be stored in
      # the Md object.
      #
      # @macro seeAbstractWidget
      def validate
        return true if controller.devices_in_md.size >= controller.min_devices

        error_args = { raid_level: controller.md_level.to_human_string, min: controller.min_devices }
        Yast::Popup.Error(
          # TRANSLATORS: raid_level is a RAID level (e.g. RAID10); min is a number
          _("For %{raid_level}, select at least %{min} devices.") % error_args
        )
        false
      end

    private

      attr_reader :controller

      def find_devices(sids, list)
        sids.map do |sid|
          list.find { |dev| dev.sid == sid }
        end.compact
      end
    end
  end
end
