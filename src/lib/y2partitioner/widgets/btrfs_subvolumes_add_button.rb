require "yast"
require "cwm"
require "y2partitioner/widgets/btrfs_subvolumes_table"
require "y2partitioner/dialogs/btrfs_subvolume"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Widget to add a btrfs subvolume to a table
    # @see Widgets::BtrfsSubvolumesTable
    class BtrfsSubvolumesAddButton < CWM::PushButton
      attr_reader :table

      def initialize(table)
        textdomain "storage"
        @table = table
      end

      def label
        _("Add...")
      end

      def handle
        subvolume_dialog = Dialogs::BtrfsSubvolume.new(filesystem)
        result = subvolume_dialog.run

        if result == :ok
          add_subvolume(subvolume_dialog.form)
          table.refresh
        end

        nil
      end

    private

      def filesystem
        table.filesystem
      end

      def add_subvolume(form)
        filesystem.ensure_default_btrfs_subvolume

        parent = filesystem.default_btrfs_subvolume
        subvol = parent.create_btrfs_subvolume(form.path)
        subvol.nocow = form.nocow
        subvol.mountpoint = form.path
      end
    end
  end
end
