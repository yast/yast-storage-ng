# Copyright (c) [2017-2020] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast2/popup"
require "cwm/common_widgets"
require "y2partitioner/dialogs/single_step"

module Y2Partitioner
  module Dialogs
    # Dialog to create and edit a Btrfs subvolume
    #
    # Used by {Actions::AddBtrfsSubvolume} and {Actions::EditBtrfsSubvolume}.
    class BtrfsSubvolume < SingleStep
      # Constructor
      #
      # @param controller [Actions::Controllers::BtrfsSubvolume]
      def initialize(controller)
        textdomain "storage"

        super()

        @controller = controller
      end

      # @macro seeDialog
      def title
        text = _("Add subvolume to %{device}")
        text = _("Edit subvolume of %{device}") if controller.subvolume

        format(text, device: controller.filesystem.name)
      end

      # Shows widgets for the Btrfs subvolume attributes
      #
      # @macro seeDialog
      def contents
        HVSquash(
          VBox(
            Left(SubvolumePath.new(controller)),
            Left(SubvolumeNocow.new(controller))
          )
        )
      end

      private

      # @return [Actions::Controllers::BtrfsSubvolume]
      attr_reader :controller

      # Input field to set the Btrfs subvolume path
      class SubvolumePath < CWM::InputField
        UNSAFE_CHARS = "\n\t\v\r\s,".freeze
        private_constant :UNSAFE_CHARS

        # Constructor
        #
        # @param controller [Actions::Controllers::BtrfsSubvolume]
        def initialize(controller)
          @controller = controller
        end

        def label
          _("Path")
        end

        def store
          controller.subvolume_path = value
        end

        def init
          controller.exist_subvolume? ? disable : focus

          self.value = controller.subvolume_path
        end

        # Validates the subvolume path
        #
        # The following conditions are checked:
        # - The subvolume path is not empty
        # - The subvolume path does not contain unsafe characters
        # - The subvolume path starts by the default subvolume path
        # - The subvolume path is unique for the filesystem
        #
        # An error popup is shown when the path contains some error.
        #
        # @return [Boolean] true if the subvolume path is valid
        def validate
          return true if skip_validation?

          fix_path

          error = presence_error || content_error || uniqueness_error || hierarchy_error

          return true if error.nil?

          Yast2::Popup.show(error, headline: :error)

          focus
          false
        end

        # @macro seeAbstractWidget
        def help
          format(
            # TRANSLATORS: help text, where %{label} is replaced by a widget label (i.e., "Path")
            _("<p>" \
                "<b>%{label}</b> is the path of the subvolume. Note that the path should be prefixed " \
                "by the default subvolume path, typically @\\. The path cannot be modified for " \
                "existing subvolumes." \
              "</p>"),
            label: label
          )
        end

        private

        # @return [Actions::Controllers::BtrfsSubvolume]
        attr_reader :controller

        def focus
          Yast::UI.SetFocus(Id(widget_id))
        end

        # Whether to skip the validations
        #
        # Note that validations are not performed when the subvolume already exists on disk.
        #
        # @return [Boolean]
        def skip_validation?
          return false unless controller.subvolume

          controller.exist_subvolume?
        end

        # Error when the given path is empty
        #
        # @return [String, nil] nil if the path is not empty
        def presence_error
          return nil unless value.empty?

          # TRANSLATORS: error message.
          _("Empty subvolume path not allowed.")
        end

        # Error when the given path contains unsafe characters
        #
        # @return [String, nil] nil if the path does not contain unsafe characters
        def content_error
          return nil unless /[#{UNSAFE_CHARS}]/.match?(value)

          # TRANSLATORS: error message.
          _("Subvolume path contains unsafe characters. Be sure it\n" \
            "does not include spaces, tabs, line breaks, commas or\n" \
            "similar special characters.")
        end

        # Error when the given path already exists in the filesystem
        #
        # @return [String, nil] nil if the path does not exist yet
        def uniqueness_error
          return nil unless controller.exist_path?(value)

          # TRANSLATORS: error message, where %s is replaced by a path given by the user.
          format(_("Subvolume name %s already exists."), value)
        end

        # Error when the given path is part of an already existing path
        #
        # @return [String, nil] nil if the path is not part of an already existing path
        def hierarchy_error
          return nil if controller.filesystem.subvolume_can_be_created?(value)

          # TRANSLATORS: error message, where %s is replaced by a Btrfs subvolume path (e.g., "@/home").
          error = format(_("Cannot create subvolume %s."), value)

          sv = controller.filesystem.subvolume_descendants(value).first
          # TRANSLATORS: last part of the error message, where %s is replaced by a Btrfs subvolume path
          #   (e.g., "@/home").
          error << "\n" << format(_("Delete subvolume %s first."), sv.path) if sv

          error
        end

        # Updates #value by adding the subvolumes prefix
        #
        # Path should be a relative path. Starting slashes are removed. A popup message is
        # presented when the subvolumes prefix is going to be added.
        #
        # @see Y2Storage::Filesystems::Btrfs#subvolumes_prefix
        # @see Y2Storage::Filesystems::Btrfs#btrfs_subvolume_path
        def fix_path
          return if value.empty?
          return unless controller.missing_subvolumes_prefix?(value)

          message = format(
            # TRANSLATORS: error message, where %s is replaced by a Btrfs subvolume prefix (e.g., "@/").
            _("Only subvolume paths starting with \"%{prefix}\" are currently allowed!\n" \
              "Automatically prepending \"%{prefix}\" to the path of the subvolume."),
            prefix: controller.subvolumes_prefix
          )

          Yast2::Popup.show(message, headline: :warning)

          self.value = controller.add_subvolumes_prefix(value)
        end
      end

      # Input field to set the Btrfs subvolume noCoW attribute
      class SubvolumeNocow < CWM::CheckBox
        # @return [Actions::Controllers::BtrfsSubvolume]
        def initialize(controller)
          @controller = controller
        end

        def label
          # TRANSLATORS: noCoW is acronym to "not use Copy on Write" feature for BtrFS.
          # It is an expert value, so if no suitable expression exists in your language,
          # then keep it as it is.
          _("noCoW")
        end

        def store
          controller.subvolume_nocow = value
        end

        def init
          self.value = controller.subvolume_nocow
        end

        # @macro seeAbstractWidget
        def help
          format(
            # TRANSLATORS: help text, where %{label} is replaced by a widget label (i.e., "noCoW")
            _("<p>" \
                "<b>%{label}</b> shows the subvolume noCoW attribute. " \
                "If set, the subvolume explicitly does not use Btrfs copy on write feature. " \
                "Copy on write means that when something is copied, the resource is shared without " \
                "doing a real copy. The shared resource is actually copied when first write operation " \
                "is performed. With noCoW, the resource is always copied during initialization. " \
                "This is useful when runtime performace is required, so there is no risk for delaying " \
                "copy when application is running." \
              "</p>"),
            label: label
          )
        end

        private

        # @return [Actions::Controllers::BtrfsSubvolume]
        attr_reader :controller
      end
    end
  end
end
