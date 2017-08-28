require "yast"
require "y2partitioner/icons"
require "y2partitioner/widgets/blk_devices_table"
require "y2partitioner/widgets/btrfs_edit_button"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Widgets
    # Page for Btrfs filesystems
    class BtrfsPage < CWM::Page
      def initialize(pager)
        textdomain "storage"

        @pager = pager
      end

      # @macro seeAbstractWidget
      def label
        _("Btrfs")
      end

      # @macro seeCustomWidget
      def contents
        return @contents if @contents

        icon = Icons.small_icon(Icons::BTRFS)
        @contents = VBox(
          Left(
            HBox(
              Image(icon, ""),
              # TRANSLATORS: Heading
              Heading(_("Btrfs Volumes"))
            )
          ),
          table,
          HBox(BtrfsEditButton.new(table))
        )
      end

    private

      def table
        return @table unless @table.nil?
        @table = BlkDevicesTable.new(devices, @pager)
        @table.remove_columns(:start_cyl, :end_cyl)
        @table
      end

      def devices
        btrfs_filesystems.map { |f| f.plain_blk_devices.first }
      end

      # Returns all btrfs filesystems
      #
      # @return [Array<Y2Storage::Filesystems::BlkFilesystem>]
      def btrfs_filesystems
        DeviceGraphs.instance.current.filesystems.select { |f| f.type.is?(:btrfs) }
      end
    end
  end
end
