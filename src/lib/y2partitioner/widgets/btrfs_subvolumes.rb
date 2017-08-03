require "yast"
require "y2partitioner/widgets/btrfs_subvolumes_table"
require "y2partitioner/widgets/btrfs_subvolumes_add_button"
require "y2partitioner/widgets/btrfs_subvolumes_delete_button"
require "y2partitioner/device_graphs"

Yast.import "Mode"

module Y2Partitioner
  module Widgets
    # Widget to manage btrfs subvolumes of a specific filesystem
    #
    # FIXME: How to handle events directly from a CWM dialog?
    # Events for :help and :cancel buttons should be managed from the dialog,
    # for example to show a popup with the help.
    class BtrfsSubvolumes < CWM::CustomWidget
      attr_reader :filesystem

      def initialize(filesystem)
        @filesystem = filesystem

        self.handle_all_events = true
      end

      # FIXME: The help handle does not work without wizard
      #
      # This handle should belongs to the dialog
      # @see Dialogs::BtrfsSubvolumes
      def handle(event)
        handle_help if event["ID"] == :help
        nil
      end

      # FIXME: this should belongs to the dialog
      # @see Dialogs::BtrfsSubvolumes
      def help
        text = _(
          "<p>Create and remove subvolumes from a Btrfs filesystem.</p>\n"
        )

        if Yast::Mode.installation
          text += _(
            "<p>Enable automatic snapshots for a Btrfs filesystem with snapper.</p>"
          )
        end

        # TODO: widget for enabale snapshot is not implemented yet
        text += "TODO enable snapshots help"

        text
      end

      def contents
        table = Widgets::BtrfsSubvolumesTable.new(filesystem)

        VBox(
          # TODO: libstorage must manage snapshots
          HBox(HSpacing(1), Left(CheckBox(_("Enable snapshots"), false))),
          VSpacing(1),
          table,
          HBox(
            Widgets::BtrfsSubvolumesAddButton.new(table),
            Widgets::BtrfsSubvolumesDeleteButton.new(table)
          )
        )
      end

    private

      # Show help of all widgets that belong to its content
      def handle_help
        text = []
        Yast::CWM.widgets_in_contents([self]).each do |widget|
          text << widget.help if widget.respond_to?(:help)
        end
        Yast::Wizard.ShowHelp(text.join("\n"))
      end
    end
  end
end
