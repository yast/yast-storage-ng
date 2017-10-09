require "yast"
require "cwm"
require "y2partitioner/device_graphs"
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
        form = nil

        loop do
          subvolume_dialog = Dialogs::BtrfsSubvolume.new(filesystem, form)
          result = subvolume_dialog.run

          break if result != :ok

          form = subvolume_dialog.form
          subvol = add_subvolume(form.path, form.nocow)
          if subvol.shadowed?(working_graph)
            Yast::Popup.Error(format(_("Mount point %s is shadowed."), subvol.mountpoint))
            delete_subvolume(subvol)
          else
            table.refresh
            break
          end
        end

        nil
      end

    private

      def add_subvolume(path, nocow)
        filesystem.create_btrfs_subvolume(path, nocow)
      end

      def delete_subvolume(subvolume)
        filesystem.delete_btrfs_subvolume(working_graph, subvolume.path)
      end

      def filesystem
        table.filesystem
      end

      def working_graph
        DeviceGraphs.instance.current
      end
    end
  end
end
