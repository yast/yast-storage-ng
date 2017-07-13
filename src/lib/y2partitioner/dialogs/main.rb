require "yast"
require "cwm/dialog"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/overview"

Yast.import "Label"
Yast.import "Mode"
Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # main entry point to partitioner showing tree pager with all content
    class Main < CWM::Dialog
      # @return [Y2Storage::DeviceGraph] device graph with all changes done in dialog
      attr_reader :device_graph

      def initialize
        textdomain "storage"
      end

      def title
        _("Partitioner")
      end

      def contents
        MarginBox(
          0.5,
          0.5,
          Widgets::OverviewTreePager.new(DeviceGraphs.instance.current)
        )
      end

      def skip_store_for
        [:redraw]
      end

      def back_button
        # do not show back button when running on running system. See CWM::Dialog.back_button
        Yast::Mode.installation ? nil : ""
      end

      def next_button
        Yast::Mode.installation ? Yast::Label.AcceptButton : Yast::Label.FinishButton
      end

      # runs dialog.
      # @param system [Y2Storage::DeviceGraph] system graph used to detect if something
      # is going to be formatted
      # @param initial [Y2Storage::DeviceGraph] device graph to display
      # @return [Symbol] result of dialog
      def run(system, initial)
        DeviceGraphs.create_instance(system, initial)
        res = nil
        loop do
          res = super()

          next if res == :redraw
          if res == :abort && Yast::Mode.installation
            next unless Yast::Popup.ConfirmAbort(:painless)
          end

          break
        end
        @device_graph = DeviceGraphs.instance.current

        res
      end
    end
  end
end
