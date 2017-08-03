require "yast"
require "y2partitioner/dialogs/popup"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Popup dialog to create a btrfs subvolume
    class BtrfsSubvolume < Popup
      attr_reader :filesystem
      attr_reader :form

      def initialize(filesystem)
        textdomain "storage"

        @filesystem = filesystem
        @form = Form.new
      end

      def title
        _("Add subvolume")
      end

      def contents
        HVSquash(
          VBox(
            Left(SubvolumePath.new(form, filesystem: filesystem)),
            Left(SubvolumeNocow.new(form, filesystem: filesystem))
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

      # Form object for the dialog
      # Widgets use this object to storage data:
      class Form
        # @!attribute path
        #   subvolume path
        attr_accessor :path
        # @!attribute nocow
        #   subvolume nocow attribute
        attr_accessor :nocow

        def initialize
          @path = ""
          @nocow = false
        end
      end
    end
  end

  # Input field to set the subvolume path
  class SubvolumePath < CWM::InputField
    attr_reader :form
    attr_reader :filesystem

    def initialize(form, filesystem: nil)
      @form = form
      @filesystem = filesystem
    end

    def label
      _("Path")
    end

    def store
      form.path = value
    end

    def init
      focus
      self.value = form.path
    end

    def validate
      valid = true

      focus

      if value.empty?
        Yast::Popup.Message(_("Empty subvolume path not allowed."))
        valid = false
      elsif !filesystem.nil?
        fix_path
        if exist_path?
          Yast::Popup.Message(format(_("Subvolume name %s already exists."), value))
          valid = false
        end
      end

      valid
    end

  private

    def focus
      Yast::UI.SetFocus(Id(widget_id))
    end

    def fix_path
      default_path = filesystem.default_btrfs_subvolume_path
      prefix = default_path + "/"

      return value if value.start_with?(prefix)

      message = format(
        _("Only subvolume names starting with \"%s\" currently allowed!\n" \
          "Automatically prepending \"%s\" to name of subvolume."), prefix, prefix
      )
      Yast::Popup.Message(message)

      self.value = File.join(default_path, value)
    end

    def exist_path?
      filesystem.btrfs_subvolumes.any? { |s| s.path == value }
    end
  end

  # Input field to set the subvolume nocow attribute
  class SubvolumeNocow < CWM::CheckBox
    attr_reader :form
    attr_reader :filesystem

    def initialize(form, filesystem: nil)
      @form = form
      @filesystem = filesystem
    end

    def label
      _("noCoW")
    end

    def store
      form.nocow = value
    end

    def init
      self.value = form.nocow
    end
  end
end
