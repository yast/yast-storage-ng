require "yast"
require "cwm"
require "y2partitioner/widgets/btrfs_subvolumes_table"
require "y2partitioner/device_graphs"

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
          Yast::Popup.Error(_("There are any subvolume selected"))
        else
          result = Yast::Popup.YesNo(
            # TRANSLATORS: %s is the path of the subvolume to be deleted
            format(_("Really delete subvolume %s?"), subvolume.path)
          )

          if result
            delete_subvolume(subvolume)
            table.refresh
          end
        end

        nil
      end

    private

      def delete_subvolume(subvolume)
        subvolume.remove_descendants
        DeviceGraphs.instance.current.remove_device(subvolume)
      end
    end
  end
end
