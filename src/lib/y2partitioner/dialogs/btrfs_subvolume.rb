require "yast"
require "cwm"
require "y2partitioner/dialogs/popup"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Popup dialog to create a btrfs subvolume
    class BtrfsSubvolume < Popup
      attr_reader :filesystem
      attr_reader :form

      # @param filesystem [Y2Storage::Filesystems::BlkFilesystem] a btrfs filesystem
      def initialize(filesystem)
        textdomain "storage"

        @filesystem = filesystem
        @form = Form.new
      end

      def title
        _("Add subvolume")
      end

      # Shows widgets for the subvolume attributes
      def contents
        HVSquash(
          VBox(
            Left(SubvolumePath.new(form, filesystem: filesystem)),
            Left(SubvolumeNocow.new(form, filesystem: filesystem))
          )
        )
      end

      # Custom layout
      #
      # Similar to {Popup#layout} but without help button
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
      #
      # Widgets use this object to storage data
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

      # Input field to set the subvolume path
      class SubvolumePath < CWM::InputField
        attr_reader :form
        attr_reader :filesystem

        # @param form [Dialogs::BtrfsSubvolume::Form]
        # @param filesystem [Y2Storage::Filesystems::BlkFilesystem] a btrfs filesystem
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

        # Validates the path
        #
        # Path cannot be empty
        # Path must start by default subvolume path
        # Path must be uniq
        def validate
          if value.empty?
            Yast::Popup.Message(_("Empty subvolume path not allowed."))
            invalid = true
          elsif !filesystem.nil?
            fix_path
            if exist_path?
              Yast::Popup.Message(format(_("Subvolume name %s already exists."), value))
              invalid = true
            end
          end

          if invalid
            focus
            false
          else
            true
          end
        end

      private

        def focus
          Yast::UI.SetFocus(Id(widget_id))
        end

        # Updates #value by prefixing path with default subvolume path if it is necessary
        def fix_path
          default_subvolume_path = default_path
          prefix = default_subvolume_path + "/"

          return value if value.start_with?(prefix)

          message = format(
            _("Only subvolume names starting with \"%{prefix}\" currently allowed!\n" \
              "Automatically prepending \"%{prefix}\" to name of subvolume."), prefix: prefix
          )
          Yast::Popup.Message(message)

          self.value = File.join(default_subvolume_path, value)
        end

        # If a default subvolume exists, its path is consider as default path.
        # In case that the top subvolume is set as default one, the default path
        # for default btrfs subvolumes is returned.
        #
        # @see Y2Storage::Filesystems::BlkFilesystem#default_btrfs_subvolume_path
        #
        # @return [String]
        def default_path
          default_subvolume = filesystem.default_btrfs_subvolume

          if default_subvolume.nil? || default_subvolume.top_level?
            filesystem.default_btrfs_subvolume_path
          else
            default_subvolume.path
          end
        end

        # Checks if there is a subvolume with the entered path
        def exist_path?
          filesystem.btrfs_subvolumes.any? { |s| s.path == value }
        end
      end

      # Input field to set the subvolume nocow attribute
      class SubvolumeNocow < CWM::CheckBox
        attr_reader :form
        attr_reader :filesystem

        # @param form [Dialogs::BtrfsSubvolume::Form]
        # @param filesystem [Y2Storage::Filesystems::BlkFilesystem] a btrfs filesystem
        def initialize(form, filesystem: nil)
          @form = form
          @filesystem = filesystem
        end

        def label
          # TRANSLATORS: noCoW is acronym to "not use Copy on Write" feature for BtrFS.
          # It is an expert value, so if no suitable expression exists in your language,
          # then keep it as it is.
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
  end
end
