require "yast"
require "cwm"
require "y2partitioner/dialogs/popup"
require "y2storage/filesystems/btrfs"

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
        # Path must be uniq for the filesystem
        # Mount point must be uniq in the whole system
        def validate
          if value.empty?
            Yast::Popup.Error(_("Empty subvolume path not allowed."))
            invalid = true
          elsif !filesystem.nil?
            fix_path
            if exist_path?
              Yast::Popup.Error(format(_("Subvolume name %s already exists."), value))
              invalid = true
            elsif exist_mount_point?
              Yast::Popup.Error(format(_("Mount point %s already exists."), mount_point))
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
        #
        # Path should be a relative path. Starting slashes are removed. A popup message is
        # presented when the default subvolume path is going to be added.
        def fix_path
          self.value = value.sub(/^\/*/, "")

          default_subvolume_path = filesystem.default_btrfs_subvolume.path
          prefix = default_subvolume_path.empty? ? "" : default_subvolume_path + "/"

          return value if value.start_with?(prefix)

          message = format(
            _("Only subvolume names starting with \"%{prefix}\" currently allowed!\n" \
              "Automatically prepending \"%{prefix}\" to name of subvolume."), prefix: prefix
          )
          Yast::Popup.Message(message)

          self.value = File.join(default_subvolume_path, value)
        end

        # Checks if there is a subvolume with the entered path
        def exist_path?
          filesystem.btrfs_subvolumes.any? { |s| s.path == value }
        end

        # Checks if the mount point already exists in the system
        # @see Mountable#shadowed?
        #
        # @return [Boolean]
        def exist_mount_point?
          devicegraph = DeviceGraphs.instance.current
          Y2Storage::Mountable.shadowed?(devicegraph, mount_point)
        end

        # Proper mount point for the current filesystem
        # @see Y2Storage::Filesystems::Btrfs#btrfs_subvolume_mount_point
        #
        # @return [String, nil] nil if the filesystem is not mounted
        def mount_point
          filesystem.btrfs_subvolume_mount_point(value)
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
