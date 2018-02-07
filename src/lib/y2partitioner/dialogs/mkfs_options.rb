require "yast"
require "cwm/dialog"
require "y2partitioner/dialogs/popup"
require "y2partitioner/widgets/mkfs_options"

module Y2Partitioner
  module Dialogs
    # CWM Dialog to set specific mkfs options for the blk_device being formated
    class MkfsOptions < Popup
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      def title
        _("Format Options:")
      end

      def contents
        HBox(
          HSpacing(2),
          HVSquash(Widgets::MkfsOptions.new(@controller)),
          HSpacing(1)
        )
      end
    end
  end
end
