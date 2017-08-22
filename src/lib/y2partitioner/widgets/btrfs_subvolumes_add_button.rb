require "yast"
require "cwm"
require "y2partitioner/widgets/btrfs_subvolumes_table"
require "y2partitioner/dialogs/btrfs_subvolume"
require "y2partitioner/format_mount/root_subvolumes_builder"

Yast.import "Popup"

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

      def filesystem
        table.filesystem
      end

      # Creates a new subvolume with the form values
      # @see Dialogs::BtrfsSubvolume::Form
      #
      # The mount point is generated from the subvolume path and
      # the filesystem mount point.
      # @see Y2Storage::Filesystems::Btrfs#btrfs_subvolume_mount_point
      def add_subvolume(path, nocow)
        if filesystem.root?
          FormatMount::RootSubvolumesBuilder.add_subvolume(path, nocow)
        else
          filesystem.create_btrfs_subvolume(path, nocow)
        end
      end
    end
  end
end
