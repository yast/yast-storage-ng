require "yast"
require "cwm/dialog"
require "y2partitioner/widgets/format_and_mount"

module Y2Partitioner
  module Dialogs
    # CWM Dialog to set specific fstab options for the blk_device being added
    # or edited.
    class FstabOptions < CWM::Dialog
      # @param options [Y2Partitioner::FormatMount::Options]
      def initialize(options)
        textdomain "storage"

        @options = options
      end

      def title
        _("Fstab Options:")
      end

      def wizard_create_dialog(&block)
        Yast::UI.OpenDialog(layout)
        block.call
      ensure
        Yast::UI.CloseDialog()
      end

      def should_open_dialog?
        true
      end

      def contents
        HVSquash(Widgets::FstabOptions.new(@options))
      end

      def layout
        VBox(
          HSpacing(50),
          # heading text
          Left(Heading(Id(:title), title)),
          VStretch(),
          VSpacing(1),
          HBox(
            HStretch(),
            HSpacing(1),
            ReplacePoint(Id(:contents), Empty()),
            HStretch(),
            HSpacing(1)
          ),
          VSpacing(1),
          VStretch(),
          ButtonBox(
            PushButton(Id(:help), Opt(:helpButton), Yast::Label.HelpButton),
            PushButton(Id(:ok), Opt(:default), Yast::Label.OKButton),
            PushButton(Id(:cancel), Yast::Label.CancelButton)
          )
        )
      end
    end
  end
end
