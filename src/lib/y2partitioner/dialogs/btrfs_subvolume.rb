# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
      def initialize(filesystem, form = nil)
        textdomain "storage"

        @filesystem = filesystem
        @form = form || Form.new
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

        # Validates the subvolume path
        #
        # The following conditions are checked:
        # - The subvolume path is not empty
        # - The subvolume path starts by the default subvolume path
        # - The subvolume path is unique for the filesystem
        def validate
          fix_path

          valid = content_validation && uniqueness_validation && hierarchy_validation
          return true if valid

          focus
          false
        end

      private

        def focus
          Yast::UI.SetFocus(Id(widget_id))
        end

        # Validates not empty path
        # An error popup is shown when entered path is empty.
        #
        # @return [Boolean] true if path is not empty
        def content_validation
          return true unless value.empty?

          Yast::Popup.Error(_("Empty subvolume path not allowed."))
          false
        end

        # Validates not duplicated path
        # An error popup is shown when entered path already exists in the filesystem.
        #
        # @return [Boolean] true if path does not exist
        def uniqueness_validation
          return true unless exist_path?

          Yast::Popup.Error(format(_("Subvolume name %s already exists."), value))
          false
        end

        # Validate proper hierarchy
        # An error popup is shown when entered path is part of an already existing path.
        #
        # @return [Boolean] true if path is part of an already existing path
        def hierarchy_validation
          return true if filesystem.subvolume_can_be_created?(value)

          msg = format(_("Cannot create subvolume %s."), value)

          sv = filesystem.subvolume_descendants(value).first
          if sv
            msg << "\n" << format(_("Delete subvolume %s first."), sv.path)
          end

          Yast::Popup.Error(msg)
          false
        end

        # Updates #value by prefixing path with default subvolume path if it is necessary
        #
        # Path should be a relative path. Starting slashes are removed. A popup message is
        # presented when the default subvolume path is going to be added.
        #
        # @see Y2Storage::Filesystems::Btrfs#btrfs_subvolume_path
        def fix_path
          self.value = filesystem.canonical_subvolume_name(value)
          return if value.empty?

          default_subvolume_path = filesystem.default_btrfs_subvolume.path
          prefix = default_subvolume_path.empty? ? "" : default_subvolume_path + "/"

          return value if value.start_with?(prefix)

          message = format(
            _("Only subvolume names starting with \"%{prefix}\" currently allowed!\n" \
              "Automatically prepending \"%{prefix}\" to name of subvolume."), prefix: prefix
          )
          Yast::Popup.Message(message)

          self.value = filesystem.btrfs_subvolume_path(value)
        end

        # Checks if the filesystem already has a subvolume with the entered path
        # @return [Boolean]
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
