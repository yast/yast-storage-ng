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
require "y2partitioner/actions/add_lvm_vg"
require "y2partitioner/actions/add_lvm_lv"
Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Button for opening the workflow to add a volume group or logical volume
    class LvmAddButton < CWM::MenuButton
      # Constructor
      # @param table [Y2Partitioner::Widgets::ConfigurableBlkDevicesTable]
      def initialize(table)
        textdomain "storage"

        @table = table
        self.handle_all_events = true
      end

      # @macro seeAbstractWidget
      def label
        # TRANSLATORS: button label to add a volume group or logical volume
        _("Add...")
      end

      # When there is no vg, only shows an option to add a new vg.
      # Otherwise, options for adding a vg or lv are shown.
      #
      # @return [Array<[Symbol, String]>] list of menu options
      def items
        items = [[:add_volume_group, _("Volume Group")]]
        if !device_graph.lvm_vgs.empty?
          items << [:add_logical_volume, _("Logical Volume")]
        end
        items
      end

      # Runs the corresponding action for adding a logical volume or volume group
      #
      # @param event [Hash] UI event
      # @return [:redraw, nil] :redraw when the action is performed; nil otherwise
      def handle(event)
        result = case event["ID"]
        when :add_volume_group
          add_vg
        when :add_logical_volume
          add_lv
        end

        result == :finish ? :redraw : nil
      end

    private

      # @return [Y2Partitioner::Widgets::ConfigurableBlkDevicesTable]
      attr_reader :table

      # Runs action for adding a new volume group
      # @see Actions::AddLvmVg
      #
      # @return [Symbol] :finish, :abort
      def add_vg
        Actions::AddLvmVg.new.run
      end

      # Runs action for adding a new logical volume to the selected volume group
      # @see Actions::AddLvmLv
      #
      # @return [Symbol, nil] :finish, :abort. Returns nil when it is not possible
      #   to determine the volume group (see {#vg}).
      def add_lv
        if vg.nil?
          Yast::Popup.Error(_("No device selected"))
          return nil
        end

        Actions::AddLvmLv.new(vg).run
      end

      # Returns the volume group associated to the selected table row
      #
      # @note When the selected table row correspond to a logical volume,
      # the volume group to which the logical volume belongs to is returned.
      #
      # @return [Y2Storage::LvmVg, nil] returns nil when no row is selected
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

      # @return [Y2Storage::Devicegraph] current devicegraph
      def device_graph
        DeviceGraphs.instance.current
      end
    end
  end
end
