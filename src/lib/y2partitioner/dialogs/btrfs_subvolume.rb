require "yast"
require "y2partitioner/dialogs/popup"

module Y2Partitioner
  module Dialogs
    # Popup dialog to create a btrfs subvolume
    class BtrfsSubvolume < Popup
      attr_accessor :path
      attr_accessor :nocow

      def initialize
        textdomain "storage"
      end

      def title
        _("Add subvolume")
      end

      def contents
        HVSquash(
          VBox(
            Left(SubvolumePath.new(self)),
            Left(SubvolumeNocow.new(self))
          )
        )
      end

      def layout
        VBox(
          HSpacing(50),
          Left(Heading(Id(:title), title)),
          VStretch(),
          VSpacing(1),
          VBox(ReplacePoint(Id(:contents), Empty())),
          VSpacing(1),
          VStretch(),
          ButtonBox(
            PushButton(Id(:ok), Opt(:default), Yast::Label.OKButton),
            PushButton(Id(:cancel), Yast::Label.CancelButton)
          )
        )
      end
    end
  end

  # Input field to set the subvolume path
  class SubvolumePath < CWM::InputField
    attr_reader :dialog

    def initialize(dialog)
      @dialog = dialog
    end

    def label
      _("Path")
    end

    def store
      dialog.path = value
    end

    def init
      focus
      self.value = dialog.path
    end

  private

    def focus
      Yast::UI.SetFocus(Id(widget_id))
    end
  end

  # Input field to set the subvolume nocow attribute
  class SubvolumeNocow < CWM::CheckBox
    attr_reader :dialog

    def initialize(dialog)
      @dialog = dialog
    end

    def label
      _("noCoW")
    end

    def store
      dialog.nocow = value
    end

    def init
      self.value = dialog.nocow || false
    end
  end
end
