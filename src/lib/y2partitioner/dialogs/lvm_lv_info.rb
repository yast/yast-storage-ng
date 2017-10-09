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
        HVSquash(NameWidget.new(@controller))
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
    end
  end
end
