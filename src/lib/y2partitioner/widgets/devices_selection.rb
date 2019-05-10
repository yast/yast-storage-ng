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
require "cwm/widget"
require "cwm/table"
require "y2partitioner/widgets/blk_devices_table"

Yast.import "UI"

module Y2Partitioner
  module Widgets
    # Abstract widget to select a set of block devices from a list.
    #
    # It displays two list with available and selected devices, allowing the
    # user to move devices between the lists.
    #
    # The subclasses are expected to implement the logic to actually access and
    # manipulate the lists.
    class DevicesSelection < CWM::CustomWidget
      # @return [Array<Y2Storage::BlkDevice>] devices currently in the 'selected' list
      abstract_method :selected
      alias_method :value, :selected

      # @return [Array<Y2Storage::BlkDevice>] devices currently in the 'available' list
      abstract_method :unselected

      def initialize
        textdomain "storage"

        @unselected_table = DevicesTable.new(unselected, "unselected")
        @selected_table   = DevicesTable.new(selected, "selected")
        self.handle_all_events = true
      end

      # @macro seeCustomWidget
      def contents
        HBox(
          HWeight(
            1,
            VBox(
              Left(Label(unselected_label)),
              @unselected_table,
              ReplacePoint(Id(:unselected_size), Empty())
            )
          ),
          MarginBox(
            1,
            1,
            HSquash(
              VBox(*selection_buttons)
            )
          ),
          HWeight(
            1,
            VBox(
              Left(Label(selected_label)),
              @selected_table,
              ReplacePoint(Id(:selected_size), Empty())
            )
          ),
          right_area
        )
      end

      # @macro seeAbstractWidget
      def handle(event)
        id = event["ID"]
        return nil unless id

        case id.to_sym
        when :unselected, :add
          select(sids_for(@unselected_table.value))
          refresh
        when :selected, :remove
          unselect(sids_for(@selected_table.value))
          refresh
        when :add_all
          select_all
          refresh
        when :remove_all
          unselect_all
          refresh
        end

        nil
      end

      # @macro seeAbstractWidget
      def init
        refresh_sizes
      end

      # Synchronize the widget view with the internal status
      def refresh
        @selected_table.devices = selected
        @selected_table.refresh
        @unselected_table.devices = unselected
        @unselected_table.refresh
        refresh_sizes
      end

      # Updates the UI to reflect the size of both lists of devices
      def refresh_sizes
        if selected_size
          # TRANSLATORS: %s is a disk size. E.g. "10.5 GiB"
          widget = Left(Label(_("Resulting size: %s") % selected_size.to_human_string))
          Yast::UI.ReplaceWidget(Id(:selected_size), widget)
        end

        if unselected_size
          # TRANSLATORS: %s is a disk size. E.g. "10.5 GiB"
          widget = Left(Label(_("Total size: %s") % unselected_size.to_human_string))
          Yast::UI.ReplaceWidget(Id(:unselected_size), widget)
        end
      end

    protected

      def selected_label
        _("Selected Devices:")
      end

      def unselected_label
        _("Available Devices:")
      end

      # Content at the right of the two lists of devices, empty by default.
      #
      # To be redefined by descending class so the area can be used to place
      # additional controls or information, like the buttons used to reorder the
      # elements of a RAID.
      #
      # @return [CWM::WidgetTerm]
      def right_area
        Empty()
      end

      def selection_buttons
        [
          # push button text
          PushButton(
            Id(:add),
            Opt(:hstretch),
            _("Add") + " " + Yast::UI.Glyph(:ArrowRight)
          ),
          # push button text
          PushButton(
            Id(:add_all),
            Opt(:hstretch),
            _("Add All") + " " + Yast::UI.Glyph(:ArrowRight)
          ),
          VSpacing(1),
          # push button text
          PushButton(
            Id(:remove),
            Opt(:hstretch),
            Yast::UI.Glyph(:ArrowLeft) + " " + _("Remove")
          ),
          # push button text
          PushButton(
            Id(:remove_all),
            Opt(:hstretch),
            Yast::UI.Glyph(:ArrowLeft) + " " + _("Remove All")
          )
        ]
      end

      # Total size of the selection
      #
      # The default implementation is to simply sum the sizes of all selected
      # devices. To be redefined in the subclasses for more specific behavior.
      #
      # @return [Y2Storage::DiskSize]
      def selected_size
        Y2Storage::DiskSize.sum(selected.map(&:size))
      end

      # Total size of the unselected devices
      #
      # The default implementation is to simply sum the sizes of all non
      # selected devices. To be redefined in the subclasses for more specific
      # behavior.
      #
      # @return [Y2Storage::DiskSize]
      def unselected_size
        Y2Storage::DiskSize.sum(unselected.map(&:size))
      end

      # Move some devices from #unselected to #selected
      #
      # To be implemented by the subclasses
      #
      # @param sids [Array<Integer>] sids of the devices to move
      def select(sids)
        raise NotImplementedError, "I don't know how to move #{sids}"
      end

      # Move some devices from #selected to #unselected
      #
      # To be implemented by the subclasses
      #
      # @param sids [Array<Integer>] sids of the devices to move
      def unselect(sids)
        raise NotImplementedError, "I don't know how to move #{sids}"
      end

      # @param records [Array<String>] ids of the selected rows in the table
      def sids_for(records)
        records.map { |i| i.split(":").last.to_i }
      end

      # Move all the devices from #unselected to #selected
      #
      # By default, it simply calls {#select} for all the unselected devices.
      # To be redefined in the subclasses for a more efficient behavior, if
      # possible.
      def select_all
        select(unselected.map(&:sid))
      end

      # Move all the devices from #selected to #unselected
      #
      # By default, it simply calls {#unselect} for all the selected devices.
      # To be redefined in the subclasses for a more efficient behavior, if
      # possible.
      def unselect_all
        unselect(selected.map(&:sid))
      end

      # Table part of the widget
      class DevicesTable < BlkDevicesTable
        # @return [Array<Y2Storage::BlkDevice>] devices in the table
        attr_accessor :devices

        # @return [String] id of the widget in Libyui
        attr_reader :widget_id

        def initialize(devices, widget_id)
          textdomain "storage"
          @devices = devices
          @widget_id = widget_id.to_s
        end

        # @macro seeAbstractWidget
        def opt
          [:keepSorting, :multiSelection, :notify]
        end

        # @see BlkDevicesTable
        def columns
          [:device, :size, :encrypted, :type]
        end

        # @see BlkDevicesTable
        def row_id(device)
          "#{widget_id}:device:#{device.sid}"
        end

        # Updates the table content ensuring the selected rows remain selected
        # if possible, even if they changed their position.
        #
        # Keeping the selection makes possible for the user to chain several
        # actions on the same devices (for example, when ordering).
        def refresh
          current_value = value
          super
          self.value = current_value
        end
      end
    end
  end
end
