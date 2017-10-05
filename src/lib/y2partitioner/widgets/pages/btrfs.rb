require "yast"
require "y2partitioner/icons"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/btrfs_edit_button"

module Y2Partitioner
  module Widgets
    module Pages
      # Page for Btrfs filesystems
      class Btrfs < CWM::Page
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

        # A Btrfs table is a table of devices formatted as BtrFS
        #
        # @return [ConfigurableBlkDevicesTable]
        def table
          return @table unless @table.nil?
          @table = ConfigurableBlkDevicesTable.new(devices, @pager)
          @table.remove_columns(:start, :end)
          @table
        end

        # Devices formatted as BtrFS
        #
        # @return [Array<Y2Storage::BlkDevice>]
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
end
