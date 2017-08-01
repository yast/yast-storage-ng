require "yast"
require "cwm/table"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Table widget to represent the btrfs subvolumes of a specific filesystem
    class BtrfsSubvolumesTable < CWM::Table
      include Help

      attr_reader :filesystem

      # @param filesystem [BlkFilesystem] a btrfs filesystem
      def initialize(filesystem)
        textdomain "storage"

        @filesystem = filesystem
      end

      def header
        columns.map { |c| send("#{c}_title") }
      end

      def items
        subvolumes.map { |s| values_for(s) }
      end

      def refresh
        change_items(items)
      end

      def selected_subvolume
        return nil if items.empty? || !value

        path = value[/table:subvolume:(.*)/, 1]
        filesystem.find_btrfs_subvolume_by_path(path)
      end

    private

      def columns
        [:path, :nocow]
      end

      def values_for(subvolume)
        [row_id(subvolume)] + columns.map { |c| send("#{c}_value", subvolume) }
      end

      def row_id(subvolume)
        "table:subvolume:#{subvolume.path}"
      end

      # Top level and default subvolumes should not be listed
      def subvolumes
        filesystem.btrfs_subvolumes.select do |subvolume|
          !subvolume.top_level? && !subvolume.default_btrfs_subvolume?
        end
      end

      # FIXME: BtrFS could belong to several devices
      def device(filesystem)
        filesystem.plain_blk_devices.first
      end

      # Column titles

      def path_title
        # TRANSLATORS: table header, subvolume path e.g. "@/home"
        _("Path")
      end

      def nocow_title
        # TRANSLATORS: table header, nocow subvolume attribute
        Center(_("noCoW"))
      end

      # Values

      def path_value(subvolume)
        subvolume.path
      end

      def nocow_value(subvolume)
        subvolume.nocow? ? _("Yes") : _("No")
      end
    end
  end
end
