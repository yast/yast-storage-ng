require "yast"
require "cwm"
require "y2partitioner/widgets/btrfs_subvolumes_table"
require "y2partitioner/device_graphs"
require "y2partitioner/format_mount/root_subvolumes_builder"

Yast.import "Popup"

module Y2Partitioner
  module Widgets
    # Widget to delete a btrfs subvolume from a table
    # @see Widgets::BtrfsSubvolumesTable
    class BtrfsSubvolumesDeleteButton < CWM::PushButton
      attr_reader :table

      # @param table [Widgets::BtrfsSubvolumesTable]
      def initialize(table)
        textdomain "storage"
        @table = table
      end

      # Widget label
      def label
        _("Delete...")
      end

      # Deletes a subvolume
      #
      # A confirmation popup is showed before deleting the subvolume.
      # An error message is presented when there is no selected table row.
      def handle
        subvolume = table.selected_subvolume

        if subvolume.nil?
          Yast::Popup.Error(_("Nothing selected"))
        else
          result = Yast::Popup.YesNo(
            # TRANSLATORS: %s is the path of the subvolume to be deleted
            format(_("Really delete subvolume %s?"), subvolume.path)
          )

          if result
            remove_subvolume(subvolume.path)
            table.refresh
          end
        end

        nil
      end

    private

      def filesystem
        table.filesystem
      end

      def remove_subvolume(path)
        if filesystem.root?
          FormatMount::RootSubvolumesBuilder.remove_subvolume(path)
        else
          devicegraph = DeviceGraphs.instance.current
          filesystem.delete_btrfs_subvolume(devicegraph, path)
        end
      end

    end
  end
end
