require "yast"
require "cwm/dialog"
require "cwm/common_widgets"
require "y2partitioner/widgets/devices_selection"

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Form to set the name, extent size and devices of a volume group
    class LvmVg < CWM::Dialog
      # Constructor
      #
      # @param controller [Actions::Controllers::LvmVg]
      def initialize(controller)
        textdomain "storage"
        @controller = controller
      end

      # @macro seeDialog
      def title
        _("Add Volume Group")
      end

      # @macro seeDialog
      def contents
        VBox(
          Left(HVSquash(NameWidget.new(controller))),
          Left(HVSquash(ExtentSizeWidget.new(controller))),
          DevicesWidget.new(controller)
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
          %i(editable notify)
        end

        # @macro seeAbstractWidget
        def label
          # TRANSLATORS: field to enter the extent size of a new volume group
          _("Physical Extent Size")
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

      # Widget making possible to add and remove physical volumes to the volume group
      class DevicesWidget < Widgets::DevicesSelection
        # Constructor
        #
        # @param controller [Actions::Controllers::LvmVg]
        def initialize(controller)
          @controller = controller
          super()
        end

        # @see Widgets::DevicesSelection#selected
        def selected
          controller.devices_in_vg
        end

        # @see Widgets::DevicesSelection#selected_size
        def selected_size
          controller.vg_size
        end

        # @see Widgets::DevicesSelection#unselected
        def unselected
          controller.available_devices
        end

        # @see Widgets::DevicesSelection#select
        def select(sids)
          find_by_sid(unselected, sids).each do |device|
            controller.add_device(device)
          end
        end

        # @see Widgets::DevicesSelection#unselect
        def unselect(sids)
          find_by_sid(selected, sids).each do |device|
            controller.remove_device(device)
          end
        end

        # Validates that at least one physical volume was added to the volume group
        # @macro seeAbstractWidget
        #
        # @note An error popup is shown when no physical volume was added.
        #
        # @return [Boolean]
        def validate
          return true if controller.devices_in_vg.size > 0

          Yast::Popup.Error(_("Select at least one device."))
          false
        end

      private

        # @return [Actions::Controllers::LvmVg]
        attr_reader :controller

        # Finds devices by sid
        #
        # @param devices [Array<Y2Storage::BlkDevice>]
        # @param sids [Array<Integer>]
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def find_by_sid(devices, sids)
          devices.select { |d| sids.include?(d.sid) }
        end
      end
    end
  end
end
