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
          add_subvolume(subvolume_dialog.form)
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
      # @see #mountpoint
      def add_subvolume(form)
        parent = filesystem.default_btrfs_subvolume
        subvol = parent.create_btrfs_subvolume(form.path)
        subvol.nocow = form.nocow
        subvol.mountpoint = mountpoint(form.path)
      end

      # Generates the subvolume mount point
      #
      # The subvolume mount point is generated from the subvolume path and
      # the filesystem mount point.
      def mountpoint(path)
        File.join(filesystem.mountpoint, subvolume_relative_path(path))
      end

      def subvolume_relative_path(path)
        path.sub(btrfs_root_path, "")
      end

      def btrfs_root_path
        filesystem.default_btrfs_subvolume.path + "/"
      end
    end
  end
end
