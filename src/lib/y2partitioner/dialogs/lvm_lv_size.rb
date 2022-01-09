# Copyright (c) [2017-2021] SUSE LLC
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
require "yast2/popup"
require "y2storage"
require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/controller_radio_buttons"
require "y2partitioner/size_parser"

module Y2Partitioner
  module Dialogs
    # Determine the size of a logical volume to be created and its number of stripes.
    #
    # Part of {Actions::AddLvmLv}.
    class LvmLvSize < Base
      # @param controller [Actions::Controllers::LvmLv] a LV controller, collecting data for a logical
      #   volume to be created
      def initialize(controller)
        super()
        textdomain "storage"
        @controller = controller
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(LvSizeWidget.new(@controller))
      end

      # Widget to choose the size and stripes for a new logical volume
      class LvSizeWidget < CWM::CustomWidget
        # @param controller [Actions::Controllers::LvmLv]
        def initialize(controller)
          super()
          textdomain "storage"

          @controller = controller
        end

        # @macro seeDialog
        def contents
          VBox(
            Left(size_widget),
            VSpacing(),
            Left(stripes_widget)
          )
        end

        # Validates the selected values
        #
        # If there are errors, then it shows a popup with the first one.
        #
        # @macro seeAbstractWidget
        #
        # @return [Boolean]
        def validate
          errors = send(:errors)

          return true if errors.none?

          Yast2::Popup.show(errors.first, headline: :error)

          size_widget.focus

          false
        end

        private

        # @return [Actions::Controllers::LvmLv]
        attr_reader :controller

        # Widget to select the size
        #
        # @return [SizeWidget]
        def size_widget
          @size_widget ||= SizeWidget.new(controller)
        end

        # Widget to select the stripe values
        #
        # @return [StripesWidget]
        def stripes_widget
          @stripes_widget ||= StripesWidget.new(controller)
        end

        # Currently selected size
        #
        # @return [Y2Storage::DiskSize, nil]
        def size
          size_widget.size
        end

        # Minimum admissible size for the logical volume
        #
        # @return [Y2Storage::DiskSize, nil]
        def min_size
          controller.min_size
        end

        # Maximum admissible size for the logical volume
        #
        # @return [Y2Storage::DiskSize, nil]
        def max_size
          controller.max_size
        end

        # Errors in the selected values
        #
        # @return [Array<String>]
        def errors
          [lv_size_error, striped_lv_size_error].compact
        end

        # Error when the given size is not valid or is out of the accepted values
        #
        # @return [String, nil]
        def lv_size_error
          return nil unless size.nil? || size < min_size || size > max_size

          # error message, :min and :max are replaced by sizes
          format(_("The size entered is invalid. Enter a size between %{min} and %{max}."),
            min: min_size.human_ceil,
            max: max_size.human_floor)
        end

        # Error when the configuring a striped volume and the given size is not valid
        #
        # @return [String, nil]
        def striped_lv_size_error
          stripes = stripes_widget.stripes_number

          return nil if stripes == 1 || size.nil?
          return nil if controller.vg.size_for_striped_lv?(size, stripes)

          format(
            # TRANSLATORS: Error message, where %{stripes} is replaced by a number (e.g., 1) and
            #   %{max_size} is replaced by a device size (e.g., 4 GiB).
            _("The maximum size of a striped volume is limited by the number of stripes and the size " \
              "of the physical volumes. According to the current configuration of the volume group, " \
              "the maximum size for a striped volume with %{stripes} stripes cannot be bigger than " \
              "%{max_size}. Please, adjust the selected size.\n\n" \
              "Also consider the size of other striped volumes. Otherwise the volume group might not " \
              "be able to allocate all the striped volumes."),
            stripes:  stripes,
            max_size: controller.vg.max_size_for_striped_lv(stripes)
          )
        end
      end

      # Choose a size for a new logical volume either choosing the maximum or
      # entering a custom size
      class SizeWidget < Widgets::ControllerRadioButtons
        # @param controller [Actions::Controllers::LvmLv]
        #   a controller collecting data for a LV to be created
        def initialize(controller)
          super()
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Size")
        end

        # @see Widgets::ControllerRadioButtons
        def items
          # TRANSLATORS: %s is a size like '15.00 GiB'
          max_size_label = _("Maximum Size (%s)") % max_size.human_floor
          [
            [:max_size, max_size_label],
            [:custom_size, _("Custom Size")]
          ]
        end

        # @see Widgets::ControllerRadioButtons
        def widgets
          [max_size_widget, custom_size_widget]
        end

        def focus
          custom_size_widget.focus
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.size_choice
          # trigger disabling the other subwidgets
          handle("ID" => value)
        end

        # @macro seeAbstractWidget
        def store
          controller.size_choice = value
          controller.size = current_widget.size
        end

        # @return [Symbol]
        def size_choice
          value
        end

        # @return [Y2Storage::DiskSize, nil]
        def size
          current_widget.size
        end

        private

        # @return [Actions::Controllers::LvmLv]
        attr_reader :controller

        # Widget to select the maximum admissible size
        #
        # @return [MaxSizeDummy]
        def max_size_widget
          @max_size_widget ||= MaxSizeDummy.new(max_size)
        end

        # Widget to give a customized size
        #
        # @return [CustomSizeInput]
        def custom_size_widget
          @custom_size_widget ||= CustomSizeInput.new(initial_size)
        end

        # Maximum possible size
        #
        # @return [Y2Storage::DiskSize]
        def max_size
          controller.max_size
        end

        # Initial size
        #
        # @return [Y2Storage::DiskSize]
        def initial_size
          controller.size || max_size
        end
      end

      # An invisible widget that remembers the max possible size
      class MaxSizeDummy < CWM::Empty
        attr_reader :size

        # @param size [Y2Storage::DiskSize]
        def initialize(size)
          super()
          @size = size
        end
      end

      # Enter a human readable size
      class CustomSizeInput < CWM::InputField
        include SizeParser

        # @param initial [Y2Storage::DiskSize]
        def initialize(initial)
          super()
          textdomain "storage"
          @initial = initial
        end

        # @macro seeAbstractWidget
        def label
          _("Size")
        end

        # @macro seeAbstractWidget
        def help
          _("<p><b>Size:</b> The size of this logical volume. " \
            "Many filesystem types (e.g., Btrfs, XFS, Ext2/3/4) " \
            "can be enlarged later if needed." \
            "</p>")
        end

        # @macro seeAbstractWidget
        def init
          self.value = initial
        end

        # @return [Y2Storage::DiskSize,nil]
        def value
          parse_user_size(super)
        end

        alias_method :size, :value

        # @param disk_size [Y2Storage::DiskSize]
        def value=(disk_size)
          super(disk_size.human_floor)
        end

        def focus
          Yast::UI.SetFocus(Id(widget_id))
        end

        private

        # @return [Y2Storage::DiskSize]
        attr_reader :initial
      end

      # Choose stripes number and size for a new logical volume
      class StripesWidget < CWM::CustomWidget
        # @param controller [Actions::Controllers::LvmLv]
        #   a controller collecting data for a LV to be created
        def initialize(controller)
          super()
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def contents
          Frame(
            _("Stripes"),
            HBox(
              stripes_number_widget,
              stripes_size_widget
            )
          )
        end

        # @macro seeAbstractWidget
        def help
          _("<p><b>Stripes:</b> How to distribute data of this logical volume "\
            "over different physical volumes for better performance.</p>")
        end

        # Disables widgets related to stripes values when the selected lv type is thin volume
        #
        # @see #disable_widgets
        def init
          disable_widgets if @controller.lv_type.is?(:thin)
        end

        def store
          @controller.stripes_number = stripes_number_widget.value
          @controller.stripes_size = stripes_size_widget.value
        end

        # @return [Integer]
        def stripes_number
          stripes_number_widget.value
        end

        # @return [Y2Storage::DiskSize]
        def stripes_size
          stripes_size_widget.value
        end

        private

        # Widget to select stripes number
        #
        # @return [StripesNumberSelector]
        def stripes_number_widget
          @stripes_number_widget ||= StripesNumberSelector.new(@controller)
        end

        # Widget to select stripes size
        #
        # @return [StripesSizeSelector]
        def stripes_size_widget
          @stripes_size_widget ||= StripesSizeSelector.new(@controller)
        end

        def disable_widgets
          stripes_number_widget.disable
          stripes_size_widget.disable
        end
      end

      # Selector for the stripes number
      class StripesNumberSelector < CWM::ComboBox
        # @param controller [Actions::Controllers::LvmLv]
        #   a controller collecting data for a LV to be created
        def initialize(controller)
          super()
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Number")
        end

        def init
          self.value = @controller.stripes_number
        end

        def items
          @controller.stripes_number_options.map { |n| [n, n.to_s] }
        end
      end

      # Selector for the stripes size
      class StripesSizeSelector < CWM::ComboBox
        # @param controller [Actions::Controllers::LvmLv]
        #   a controller collecting data for a LV to be created
        def initialize(controller)
          super()
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Size")
        end

        def init
          self.value = @controller.stripes_size.to_s
        end

        def items
          @controller.stripes_size_options.map { |s| [s.to_s, s.to_s] }
        end

        # @return [Y2Storage::DiskSize]
        def value
          Y2Storage::DiskSize.new(super)
        end
      end
    end
  end
end
