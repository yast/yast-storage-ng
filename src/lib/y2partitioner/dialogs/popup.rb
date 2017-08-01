require "yast"
require "cwm/dialog"

module Y2Partitioner
  module Dialogs
    # Adapt CWM dialog to allow popup dialogs
    class Popup < CWM::Dialog
      def wizard_create_dialog(&block)
        Yast::UI.OpenDialog(layout)
        block.call
      ensure
        Yast::UI.CloseDialog()
      end

      def should_open_dialog?
        true
      end

      def layout
        VBox(
          HSpacing(50),
          Left(Heading(Id(:title), title)),
          VStretch(),
          VSpacing(1),
          MinSize(50, 18, ReplacePoint(Id(:contents), Empty())),
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
