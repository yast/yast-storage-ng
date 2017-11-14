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
        # Checks whether the given value is valid
        #
        # @note An error popup is shown when necessary.
        #
        # @return [Boolean]
        def validate
          focus
          presence_validation && legal_characters_validation && uniqueness_validation
        end

      private

        # @return [Actions::Controllers::LvmVg]
        attr_reader :controller

        # Sets the focus into this widget
        def focus
          Yast::UI.SetFocus(Id(widget_id))
        end

        # Checks whether some value was entered
        #
        # @return [Boolean]
        def presence_validation
          return true unless controller.empty_vg_name?

          Yast::Popup.Error(
            _("Enter a name for the volume group.")
          )

          false
        end

        # Checks whether the entered value has only legal characters
        #
        # @return [Boolean]
        def legal_characters_validation
          return true unless controller.illegal_vg_name?

          Yast::Popup.Error(
            _("The name for the volume group contains illegal characters. Allowed\n" \
              "are alphanumeric characters, \".\", \"_\", \"-\" and \"+\"")
          )

          false
        end

        # Checks whether there is not another device with the entered name
        #
        # @return [Boolean]
        def uniqueness_validation
          return true unless controller.duplicated_vg_name?

          Yast::Popup.Error(
            format(
              _("The volume group name \"%{vg_name}\" conflicts\n" \
                "with another entry in the /dev directory."),
              vg_name: controller.vg_name
            )
          )

          false
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
        # Checks whether the given value is valid
        #
        # @note An error popup is shown when necessary.
        #
        # @return [Boolean]
        def validate
          return true unless controller.invalid_extent_size?

          Yast::Popup.Error(
            _("The data entered in invalid. Insert a physical extent size larger than 1 KiB\n" \
              "in powers of 2 and multiple of 128 KiB, for example, \"512 KiB\" or \"4 MiB\"")
          )

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

        # Validates physical volume was added to the volume group
        # @macro seeAbstractWidget
        #
        # @note An error popup is shown when necessary.
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
