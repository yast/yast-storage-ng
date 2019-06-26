require "yast"
require "cwm/table"
require "y2partitioner/widgets/help"

module Y2Partitioner
  module Widgets
    # Table widget to represent the btrfs subvolumes of a specific filesystem
    class BtrfsSubvolumesTable < CWM::Table
      include Help

      attr_reader :filesystem

      # @param filesystem [Y2Storage::Filesystems::BlkFilesystem] a btrfs filesystem
      def initialize(filesystem)
        textdomain "storage"

        @filesystem = filesystem
      end

      # Table header
      def header
        columns.map { |c| send("#{c}_title") }
      end

      # Items do not include top level and defatul btrfs subvolumes
      #
      # @see Y2Storage::BtrfsSubvolume#top_level?
      # @see Y2Storage::BtrfsSubvolume#default_btrfs_subvolume?
      def items
        subvolumes.map { |s| values_for(s) }
      end

      # Updates table content
      def refresh
        change_items(items)
      end

      # Returns the selected subvolume
      #
      # @return [BtrfsSubvolume, nil] nil if anything is selected
      def selected_subvolume
        return nil if items.empty? || !value

        path = value[/table:subvolume:(.*)/, 1]
        filesystem.find_btrfs_subvolume_by_path(path)
      end

      # Builds the help, including columns help
      def help
        text = []

        text << _("<p>The table contains:</p>")

        columns.each do |column|
          help_method = "#{column}_help"
          text << "<p>" + send(help_method) + "</p>" if respond_to?(help_method, true)
        end

        text.join("\n")
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

      # Column titles
      def path_title
        # TRANSLATORS: table header, subvolume path e.g. "@/home"
        _("Path")
      end

      def nocow_title
        # TRANSLATORS: table header, nocow subvolume attribute (do not use copy
        # on write feature)
        Center(_("noCoW"))
      end

      # Values

      def path_value(subvolume)
        subvolume.path
      end

      def nocow_value(subvolume)
        subvolume.nocow? ? _("Yes") : _("No")
      end

      # Help

      def path_help
        _("<b>Path</b> shows the subvolume path.")
      end

      def nocow_help
        _("<b>noCoW</b> shows the subvolume noCoW attribute. " \
          "If set, the subvolume explicitly does not use Btrfs copy on write feature. " \
          "Copy on write means that when something is copied, the resource is shared without " \
          "doing a real copy. The shared resource is actually copied when first write operation " \
          "is performed. With noCoW, the resource is always copied during initialization. " \
          "This is useful when runtime performace is required, so there is no risk for delaying " \
          "copy when application is running.")
      end
    end
  end
end
