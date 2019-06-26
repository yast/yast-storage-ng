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
require "y2storage"
require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/controller_radio_buttons"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Form to enter the basic information about a logical volume to be created,
    # like the name and type
    #
    # Part of {Actions::AddLvmLv}.
    class LvmLvInfo < Base
      # @param controller [Actions::Controllers::LvmLv]
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
            LvTypeSelector.new(@controller)
          )
        )
      end

      # Name of the logical volume
      class NameWidget < CWM::InputField
        # @param controller [Actions::Controllers::LvmLv]
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
        def help
          _("<p><b>Name:</b> A name to identify this logical volume. " \
            "Do not start this with \"/dev/&lt;vg-name&gt;/\"; " \
            "this is automatically added." \
            "</p>")
        end

        # @macro seeAbstractWidget
        def init
          self.value = @controller.lv_name
          Yast::UI.SetFocus(Id(widget_id))
        end

        # @macro seeAbstractWidget
        def store
          @controller.lv_name = value
        end

        # @macro seeAbstractWidget
        # @see Actions::Controllers::LvmLv#name_errors
        def validate
          errors = @controller.name_errors(value)
          return true if errors.empty?

          Yast::Popup.Error(errors.first)
          Yast::UI.SetFocus(Id(widget_id))
          false
        end
      end

      # Widget to select the type of the new logical volume (normal, thin or thin pool)
      #
      # When the selected type is :thin, it also allows to select a thin pool (see {ThinPoolSelector}).
      class LvTypeSelector < Widgets::ControllerRadioButtons
        # @param controller [Actions::Controllers::LvmLv]
        #   a controller collecting data for a LV to be created
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Type")
        end

        # @macro seeAbstractWidget
        def help
          _("<p><b>Type:</b> How to reserve disk space for the logical volume.</p>")
        end

        # @see Widgets::ControllerRadioButtons
        def items
          [
            [NORMAL_VOLUME_OPTION, _("Normal Volume")],
            [THIN_POOL_OPTION, _("Thin Pool")],
            [THIN_VOLUME_OPTION, _("Thin Volume")]
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
        # Sets the current lv type and disables widgets that cannot be selected
        #
        # @see Actions::Controllers::LvmLv#lv_type
        # @see #disable_options
        def init
          self.value = @controller.lv_type.to_sym
          disable_options

          # trigger unselecting the other radio buttons
          handle("ID" => value)
        end

        # @macro seeAbstractWidget
        # Stores the selected lv type
        #
        # @note The thin pool is also set when the selected type is thin volume.
        def store
          @controller.lv_type = selected_lv_type
          @controller.thin_pool = current_widget.value if selected_lv_type.is?(:thin)
        end

        private

        NORMAL_VOLUME_OPTION = Y2Storage::LvType::NORMAL.to_sym.freeze
        THIN_POOL_OPTION = Y2Storage::LvType::THIN_POOL.to_sym.freeze
        THIN_VOLUME_OPTION = Y2Storage::LvType::THIN.to_sym.freeze

        # Currently selected lv type (normal, pool or thin)
        #
        # @return [Y2Storage::LvType]
        def selected_lv_type
          Y2Storage::LvType.find(value)
        end

        # Disables options that cannot be selected
        #
        # Option for thin volumes is disabled when there is no available pool.
        # Options for normal or pool volumes are disabled when there is no room
        # for a new logical volume.
        def disable_options
          disable_option(THIN_VOLUME_OPTION) unless @controller.thin_lv_can_be_added?

          if !@controller.lv_can_be_added?
            disable_option(NORMAL_VOLUME_OPTION)
            disable_option(THIN_POOL_OPTION)
          end

          nil
        end

        # Disables an specific widget
        def disable_option(option)
          Yast::UI.ChangeWidget(Id(option), :Enabled, false)
        end
      end

      # Widget to select a thin pool
      class ThinPoolSelector < CWM::ComboBox
        # @param controller [Actions::Controllers::LvmLv]
        #   a controller collecting data for a LV to be created
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def label
          _("Used Pool")
        end

        # @macro seeAbstractWidget
        def init
          return if @controller.thin_pool.nil?

          self.value = @controller.thin_pool
        end

        def items
          @controller.available_thin_pools.map { |p| [p.sid, p.lv_name] }
        end

        # @return [Y2Storage::LvmLv, nil]
        def value
          @controller.available_thin_pools.find { |p| p.sid == super }
        end

        # @param lv [Y2Storage::LvmLv, nil]
        def value=(lv)
          super(lv&.sid)
        end
      end
    end
  end
end
