require "yast"
require "cwm"
require "y2partitioner/sequences/edit_blk_device"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Button for opening the editing workflow (basically mount and format
    # options) on a block device.
    class EditBlkDeviceButton < CWM::PushButton
      # Constructor
      # @param device [Y2Storage::BlkDevice]
      # @param table [Y2Partitioner::Widgets::ConfigurableBlkDevicesTable]
      def initialize(device: nil, table: nil)
        textdomain "storage"

        unless device || table
          raise ArgumentError, "Please provide either a block device or a table with devices"
        end

        @device = device
        @table = table
      end

      def label
        _("Edit...")
      end

      # @macro seeAbstractWidget
      def handle
        if device.nil?
          Yast::Popup.Error(_("No device selected"))
          return nil
        end

        Sequences::EditBlkDevice.new(device).run

        # sym == :next ? :redraw : nil
        # must redraw because we've replaced the original dialog contents!
        :redraw
      end

    protected

      # Device to edit
      def device
        @device || @table.selected_device
      end
    end
  end
end
