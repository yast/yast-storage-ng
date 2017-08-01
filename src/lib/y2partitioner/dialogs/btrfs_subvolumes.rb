require "yast"
require "y2partitioner/widgets/btrfs_subvolumes"
require "y2partitioner/dialogs/popup"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Dialogs
    # Popup dialog to configure subvolumes and options for a btrfs filesystem
    class BtrfsSubvolumes < Popup
      attr_reader :filesystem

      def initialize(filesystem)
        textdomain "storage"

        @filesystem = filesystem
      end

      def title
        _("Edit Btrfs subvolumes")
      end

      def contents
        VBox(Widgets::BtrfsSubvolumes.new(filesystem))
      end

      # Executes changes in a transaction
      def run
        result = nil
        DeviceGraphs.instance.transaction do
          result = super
          result == :ok
        end
        result
      end
    end
  end
end
