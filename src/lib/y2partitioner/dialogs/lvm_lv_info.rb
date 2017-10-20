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
    # Form to enter the basic information about a logical volume to be created,
    # line the name and type
    # Part of {Sequences::AddLvmLv}.
    class LvmLvInfo < CWM::Dialog
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
            Frame(
              _("Name"),
              NameWidget.new(@controller)
            ),
            VSpacing(),
            TypeWidget.new(@controller)
          )
        )
      end

      # Name of the logical volume
      class NameWidget < CWM::InputField
        # @param controller [Sequences::Controllers::LvmLv]
        #   a controller collecting data for a LV to be created
        def initialize(controller)
          super()
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Logical Volume")
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.lv_name
        end

        # @macro seeAbstractWidget
        def store
          @controller.lv_name = value
        end

        # @macro seeAbstractWidget
        def validate
          error_message = nil

          if value.nil? || value.empty?
            error_message = _("Enter a name for the logical volume.")
          end

          error_message ||= @controller.error_for_lv_name(value)

          if !error_message && @controller.lv_name_in_use?(value)
            error_message =
              _(
                "A logical volume named \"%{lv_name}\" already exists\n" \
                "in volume group \"%{vg_name}\"."
              ) % { lv_name: value, vg_name: @controller.vg_name }
          end

          if error_message
            Yast::Popup.Error(error_message)
            Yast::UI.SetFocus(Id(widget_id))
            false
          else
            true
          end
        end
      end

      # Choose the type of the new logical volume (normal, thin or thin pool)
      # @note When the selected type is :thin, it also allows to select the
      #   used thin pool (see {ThinPoolSelector}).
      class TypeWidget < Widgets::ControllerRadioButtons
        # @param controller [Sequences::Controllers::LvmLv]
        #   a controller collecting data for a LV to be created
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Type")
        end

        # @see Widgets::ControllerRadioButtons
        def items
          [
            [:normal, _("Normal Volume")],
            [:thin_pool, _("Thin Pool")],
            [:thin, _("Thin Volume")]
          ]
        end

        # @see Widgets::ControllerRadioButtons
        def widgets
          @widgets ||= [
            CWM::Empty.new("normal_widget"),
            CWM::Empty.new("thin_pool_widget"),
            ThinPoolSelector.new(@controller)
          ]
        end

        # @macro seeAbstractWidget
        def init
          self.value = (@controller.type_choice ||= :normal)
          # trigger disabling the other subwidgets
          handle("ID" => value)
        end

        # @macro seeAbstractWidget
        def store
          @controller.type_choice = value
          @controller.thin_pool = current_widget.value if value == :thin
        end
      end

      # Selector for used thin pool
      # TODO: thin provisioning should be implemented in libstorage-ng
      class ThinPoolSelector < CWM::ComboBox
        # @param controller [Sequences::Controllers::LvmLv]
        #   a controller collecting data for a LV to be created
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Used Pool")
        end

        def init
          thin_pool = @controller.thin_pool
          self.value = thin_pool if thin_pool
        end

        def items
          []
        end
      end
    end
  end
end
