require "yast"
require "cwm/dialog"
require "y2partitioner/dialogs/popup"
require "y2partitioner/widgets/format_and_mount"

module Y2Partitioner
  module Dialogs
    # CWM Dialog to set specific fstab options for the blk_device being added
    # or edited.
    class FstabOptions < Popup
      # @param controller [Actions::Controllers::Filesystem]
      def initialize(controller)
        textdomain "storage"

        @controller = controller
      end

      def title
        _("Fstab Options:")
      end

      def contents
        HBox(
          HStretch(),
          HSpacing(1),
          HVSquash(Widgets::FstabOptions.new(@controller)),
          HStretch(),
          HSpacing(1)
        )
      end
    end
  end
end
