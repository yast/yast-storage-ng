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
require "y2storage"
require "cwm"
require "y2partitioner/widgets/controller_radio_buttons"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Determine the size of a logical volume to be created and its number of stripes.
    # Part of {Sequences::AddLvmLv}.
    class LvmLvSize < CWM::Dialog
      # @param controller [Sequences::Controllers::LvmLv]
      #   a LV controller, collecting data for a logical volume to be created
      def initialize(controller)
        textdomain "storage"
        @controller = controller
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        HVSquash(
          VBox(
            Left(SizeWidget.new(@controller)),
            VSpacing(),
            Left(StripesWidget.new(@controller))
          )
        )
      end

      # Choose a size for a new logical volume either choosing the maximum or
      # entering a custom size
      class SizeWidget < Widgets::ControllerRadioButtons
        # @param controller [Sequences::Controllers::LvmLv]
        #   a controller collecting data for a LV to be created
        def initialize(controller)
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
          max_size_label = _("Maximum Size (%s)") % max.human_floor
          [
            [:max_size, max_size_label],
            [:custom_size, _("Custom Size")]
          ]
        end

        # @see Widgets::ControllerRadioButtons
        def widgets
          @widgets ||= [
            MaxSizeDummy.new(max),
            CustomSizeInput.new(initial, min, max)
          ]
        end

        # @macro seeAbstractWidget
        def init
          self.value = (@controller.size_choice ||= :max_size)
          # trigger disabling the other subwidgets
          handle("ID" => value)
        end

        # @macro seeAbstractWidget
        def store
          @controller.size = current_widget.size
          @controller.size_choice = value
        end

      protected

        # @return [Y2Storage::DiskSize] minimum possible size
        def min
          @controller.min_size
        end

        # @return [Y2Storage::DiskSize] maximum possible size
        def max
          @controller.max_size
        end

        # @return [Y2Storage::DiskSize] initial size
        def initial
          @controller.size
        end
      end

      # An invisible widget that remembers the max possible size
      class MaxSizeDummy < CWM::Empty
        attr_reader :size

        # @param size [Y2Storage::DiskSize]
        def initialize(size)
          @size = size
        end
      end

      # Enter a human readable size
      class CustomSizeInput < CWM::InputField
        # @param initial [Y2Storage::DiskSize]
        # @param min [Y2Storage::DiskSize]
        # @param max [Y2Storage::DiskSize]
        def initialize(initial, min, max)
          textdomain "storage"
          @initial = initial
          @min = min
          @max = max
        end

        # @macro seeAbstractWidget
        def label
          _("Size")
        end

        # @macro seeAbstractWidget
        def init
          self.value = initial || max
        end

        # @macro seeAbstractWidget
        def validate
          return true unless value.nil? || value < min || value > max

          min_s = min.human_ceil
          max_s = max.human_floor
          Yast::Popup.Error(
            Yast::Builtins.sformat(
              # error popup, %1 and %2 are replaced by sizes
              _("The size entered is invalid. Enter a size between %1 and %2."),
              min_s, max_s
            )
          )
          Yast::UI.SetFocus(Id(widget_id))
          false
        end

        # @return [Y2Storage::DiskSize,nil]
        def value
          Y2Storage::DiskSize.from_human_string(super)
        rescue TypeError
          nil
        end

        alias_method :size, :value

        # @param v [Y2Storage::DiskSize]
        def value=(v)
          super(v.human_floor)
        end

      protected

        # @return [Y2Storage::DiskSize]
        attr_reader :initial
        # @return [Y2Storage::DiskSize]
        attr_reader :min
        # @return [Y2Storage::DiskSize]
        attr_reader :max
      end
    end

    # Choose stripes number and size for a new logical volume
    class StripesWidget < CWM::CustomWidget
      # @param controller [Sequences::Controllers::LvmLv]
      #   a controller collecting data for a LV to be created
      def initialize(controller)
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

      def store
        @controller.stripes_number = stripes_number_widget.value
        @controller.stripes_size = stripes_size_widget.value
      end

    private

      def stripes_number_widget
        @stripes_number_widget ||= StripesNumberSelector.new(@controller)
      end

      def stripes_size_widget
        @stripes_size_widget ||= StripesSizeSelector.new(@controller)
      end
    end

    # Selector for the stripes number
    class StripesNumberSelector < CWM::ComboBox
      # @param controller [Sequences::Controllers::LvmLv]
      #   a controller collecting data for a LV to be created
      def initialize(controller)
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
      # @param controller [Sequences::Controllers::LvmLv]
      #   a controller collecting data for a LV to be created
      def initialize(controller)
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
