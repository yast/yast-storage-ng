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
require "y2partitioner/sequences/add_lvm_lv"
require "y2partitioner/widgets/lvm_validations"

module Y2Partitioner
  module Widgets
    # Button for opening the workflow to add a volume group or logical volume
    class AddLvmButton < CWM::CustomWidget
      include LvmValidations

      # Constructor
      # @param table [Y2Partitioner::Widgets::ConfigurableBlkDevicesTable]
      def initialize(table)
        textdomain "storage"

        @table = table
        self.handle_all_events = true
      end

      def contents
        MenuButton(
          _("Add..."),
          [
            Item(Id(:add_volume_group), _("Volume Group")),
            Item(Id(:add_logical_volume), _("Logical Volume"))
          ]
        )
      end

      # @param event [Hash] UI event
      def handle(event)
        case event["ID"]
        when :add_volume_group
          add_vg
        when :add_logical_volume
          add_lv
        end
      end

    private

      attr_reader :table

      def add_vg
        return nil unless validate_add_vg

        Yast::Popup.Warning("Not yet implemented")
      end

      def add_lv
        return nil unless validate_add_lv(vg)

        Sequences::AddLvmLv.new(vg).run
        :redraw
      end

      def vg
        device = table.selected_device
        return nil if device.nil?

        case device
        when Y2Storage::LvmVg
          device
        when Y2Storage::LvmLv
          device.lvm_vg
        end
      end
    end
  end
end
