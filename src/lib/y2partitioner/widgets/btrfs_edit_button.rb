require "yast"
require "y2partitioner/dialogs/btrfs_subvolumes"
require "y2partitioner/widgets/blk_devices_table"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Widget to edit a Btrfs filesystem
    class BtrfsEditButton < CWM::PushButton
      attr_reader :table

      # @param table [Widgets::BtrfsTable]
      def initialize(table)
        textdomain "storage"
        @table = table
      end

      # @see CWM::PushButton#Label
      def label
        _("Edit...")
      end

      # Opens a dialog to manage the list of subvolumes. In case of there is no
      # selected table row, it shows an error.
      def handle
        filesystem = selected_filesystem

        if filesystem.nil?
          Yast::Popup.Error(_("There is no filesystem selected to edit."))
        else
          Dialogs::BtrfsSubvolumes.new(filesystem).run
        end

        nil
      end

    private

      def selected_filesystem
        device = table.selected_device
        device.nil? ? nil : device.filesystem
      end
    end
  end
end
