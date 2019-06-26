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
require "cwm/common_widgets"
require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/lvm_vg_devices_selector"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Form to set the name, extent size and devices of a volume group
    class LvmVg < Base
      # Constructor
      #
      # @param controller [Actions::Controllers::LvmVg]
      def initialize(controller)
        textdomain "storage"
        @controller = controller
      end

      # @macro seeDialog
      def title
        controller.wizard_title
      end

      # @macro seeDialog
      def contents
        VBox(
          Left(HVSquash(NameWidget.new(controller))),
          Left(HVSquash(ExtentSizeWidget.new(controller))),
          Widgets::LvmVgDevicesSelector.new(controller)
        )
      end

      private

      # @return [Actions::Controllers::LvmVg]
      attr_reader :controller

      # Widget for the LVM volume group name
      class NameWidget < CWM::InputField
        # Constructor
        #
        # @param controller [Actions::Controllers::LvmVg]
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def opt
          [:notify]
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: field to enter the name of a new volume group
          _("&Volume Group Name")
        end

        # @macro seeAbstractWidget
        def help
          # TRANSLATORS: help text
          _("<p><b>Volume Group Name:</b> The name of the volume group. " \
            "Do not start this with \"/dev/\"; this is automatically added." \
            "</p>")
        end

        # @macro seeAbstractWidget
        def init
          self.value = controller.vg_name
          focus
        end

        # @macro seeAbstractWidget
        def handle
          controller.vg_name = value
          nil
        end

        # @macro seeAbstractWidget
        # Checks whether the given volume group name is valid
        #
        # @note An error popup is shown when the name is not valid.
        #
        # @see Actions::Controllers::LvmVg#vg_name_errors
        #
        # @return [Boolean]
        def validate
          errors = controller.vg_name_errors
          return true if errors.empty?

          # When an error happens the focus should be set into this widget
          focus

          # First error is showed
          Yast::Popup.Error(errors.first)
          false
        end

        private

        # @return [Actions::Controllers::LvmVg]
        attr_reader :controller

        # Sets the focus into this widget
        def focus
          Yast::UI.SetFocus(Id(widget_id))
        end
      end

      # Widget for the LVM extent size
      class ExtentSizeWidget < CWM::ComboBox
        # @return [Actions::Controllers::LvmVg]
        attr_reader :controller

        SUGGESTED_SIZES = ["1 MiB", "2 MiB", "4 MiB", "8 MiB", "16 MiB", "32 MiB", "64 MiB"].freeze

        # Constructor
        #
        # @param controller [Actions::Controllers::LvmVg]
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def opt
          [:editable, :notify]
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: field to enter the extent size of a new volume group
          _("Physical Extent Size")
        end

        # @macro seeAbstractWidget
        def help
          # TRANSLATORS: help text
          _("<p><b>Physical Extent Size:</b> " \
            "The smallest size unit used for volumes. " \
            "This cannot be changed after creating the volume group. " \
            "You can resize a logical volume only in multiples of this size." \
            "</p>")
        end

        # @macro seeAbstractWidget
        def items
          SUGGESTED_SIZES.map { |mp| [mp, mp] }
        end

        # @macro seeAbstractWidget
        def init
          self.value = controller.extent_size.to_s
        end

        # @macro seeAbstractWidget
        def handle
          controller.extent_size = value
          nil
        end

        # @macro seeAbstractWidget
        # Checks whether the given extent size is valid
        #
        # @note An error popup is shown when the extent size is not valid.
        #
        # @see Actions::Controllers::LvmVg#extent_size_errors
        #
        # @return [Boolean]
        def validate
          errors = controller.extent_size_errors
          return true if errors.empty?

          # First error is showed
          Yast::Popup.Error(errors.first)
          false
        end
      end
    end
  end
end
