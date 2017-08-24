require "yast"
require "cwm"
require "y2partitioner/widgets/btrfs_subvolumes_table"
require "y2partitioner/dialogs/btrfs_subvolume"

module Y2Partitioner
  module Widgets
    # Widget to add a btrfs subvolume to a table
    # @see Widgets::BtrfsSubvolumesTable
    class BtrfsSubvolumesAddButton < CWM::PushButton
      attr_reader :table

      # @param table [Widgets::BtrfsSubvolumesTable]
      def initialize(table)
        textdomain "storage"
        @table = table
      end

      def label
        _("Add...")
      end

      # Shows a dialog to create a new subvolume
      #
      # The table is refreshed when a new subvolume is created
      def handle
        subvolume_dialog = Dialogs::BtrfsSubvolume.new(filesystem)
        result = subvolume_dialog.run

        if result == :ok
          form = subvolume_dialog.form
          add_subvolume(form.path, form.nocow)
          table.refresh
        end

        nil
      end

    private

      def add_subvolume(path, nocow)
        filesystem.create_btrfs_subvolume(path, nocow)
      end

      def filesystem
        table.filesystem
      end
    end
  end
end
