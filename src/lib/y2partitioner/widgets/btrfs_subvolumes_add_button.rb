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
        subvolume_dialog = Dialogs::BtrfsSubvolume.new
        result = subvolume_dialog.run

        path = subvolume_dialog.path
        nocow = subvolume_dialog.nocow

        if result == :ok
          ensure_default_subvolume

          if path.empty?
            Yast::Popup.Message(_("Empty subvolume path not allowed."))
          else
            path = fix_path(path)

            if exist_path?(path)
              Yast::Popup.Message(format(_("Subvolume name %s already exists."), path))
            else
              add_subvolume(path, nocow)
              table.refresh
            end
          end
        end

        nil
      end

    private

      DEFAULT_PATH = "@"

      def filesystem
        table.filesystem
      end

      def fix_path(path)
        default = filesystem.default_btrfs_subvolume
        prefix = default.path + "/"

        return path if path.start_with?(prefix)

        message = format(
          _("Only subvolume names starting with \"%s\" currently allowed!\n" \
            "Automatically prepending \"%s\" to name of subvolume."), prefix, prefix
        )
        Yast::Popup.Message(message)

        File.join(default.path, path)
      end

      def exist_path?(path)
        filesystem.btrfs_subvolumes.any? { |s| s.path == path }
      end

      def add_subvolume(path, nocow)
        parent = filesystem.default_btrfs_subvolume
        subvol = parent.create_btrfs_subvolume(path)
        subvol.nocow = nocow
        subvol.mountpoint = path
      end

      def ensure_default_subvolume
        subvolume = filesystem.default_btrfs_subvolume

        if subvolume.nil? || subvolume.top_level?
          subvolume = filesystem.btrfs_subvolumes.detect { |s| s.path == DEFAULT_PATH }

          if subvolume.nil?
            subvolume = create_default_subvolume
          elsif !subvolume.default_btrfs_subvolume?
            subvolume.set_default_btrfs_subvolume
          end
        end

        subvolume
      end

      def create_default_subvolume
        top_level_subvolume = filesystem.top_level_btrfs_subvolume
        subvolume = top_level_subvolume.create_btrfs_subvolume(DEFAULT_PATH)
        subvolume.nocow = false
        subvolume.mountpoint = DEFAULT_PATH
        subvolume.set_default_btrfs_subvolume
        subvolume
      end
    end
  end
end
