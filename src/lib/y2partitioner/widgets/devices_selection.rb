require "yast"
require "cwm/widget"
require "cwm/table"
require "y2partitioner/widgets/blk_device_columns"

Yast.import "UI"

module Y2Partitioner
  module Widgets
    class DevicesSelection < CWM::CustomWidget
      attr_reader :selected, :unselected
      alias_method :value, :selected

      def initialize(unselected, selected)
        textdomain "storage"

        @unselected       = unselected.dup
        @selected         = selected.dup
        @unselected_table = DevicesTable.new(@unselected, "unselected")
        @selected_table   = DevicesTable.new(@selected, "selected")
      end

      def contents
        HBox(
          HWeight(
            1,
            VBox(
              Left(Label(unselected_label)),
              @unselected_table
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
              @selected_table
            )
          )
        )
      end

      def handle(event)
        case event["ID"]
        when :add_all
          selected.concat(unselected)
          unselected.clear
          @selected_table.refresh
          @unselected_table.refresh
        end
        nil
      end


    protected

      def selected_label
        _("Selected Devices:")
      end

      def unselected_label
        _("Available Devices:")
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

      class DevicesTable < CWM::Table
        include BlkDeviceColumns

        attr_reader :devices, :widget_id

        def initialize(devices, widget_id)
          @devices = devices
          @widget_id = widget_id.to_s
        end

        def opt
         [:keepSorting, :multiSelection, :notify]
        end

        def columns
          [:device, :size, :encrypted, :type]
        end

        def row_id(device)
          "#{widget_id}:device:#{device.sid}"
        end
      end
    end
  end
end
