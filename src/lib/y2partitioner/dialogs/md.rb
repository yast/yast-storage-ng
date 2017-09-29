require "yast"
require "cwm/dialog"
require "cwm/common_widgets"
require "y2partitioner/widgets/devices_selection"

# Work around YARD inability to link across repos/gems:
# (declaring macros here works because YARD sorts by filename size(!))

# @!macro [new] seeAbstractWidget
#   @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FAbstractWidget:${0}
# @!macro [new] seeCustomWidget
#   @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FCustomWidget:${0}
# @!macro [new] seeDialog
#   @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FDialog:${0}

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Form to set the type, name and devices of an MD RAID to be created
    # Part of {Sequences::AddMd}.
    class Md < CWM::Dialog
      def initialize(controller)
        textdomain "storage"
        @controller = controller
        @dev_selection = DevicesSelection.new(controller)
        @level         = LevelChoice.new(controller, @dev_selection)
        @name          = NameEntry.new(controller)
      end

      # @macro seeDialog
      def title
        @controller.wizard_title
      end

      # @macro seeDialog
      def contents
        VBox(
          Left(
            HVSquash(
              HBox(
                @level,
                HSpacing(1),
                Top(@name)
              )
            )
          ),
          VSpacing(1),
          @dev_selection
        )
      end

    private

      attr_reader :controller

      # Widget to select the RAID level
      class LevelChoice < CWM::CustomWidget
        # @param controller [Sequences::MdController]
        # @param devices_widget [#refresh_sizes] widget containing the lists of
        #   devices selected for the RAID
        def initialize(controller, devices_widget)
          textdomain "storage"
          @controller = controller
          @devices_widget = devices_widget
        end

        # Selected option
        def value
          Yast::UI.QueryWidget(Id(:md_level_group), :Value)
        end

        # Used to initialize the widget
        def value=(val)
          Yast::UI.ChangeWidget(Id(:md_level_group), :Value, val)
        end

        # @macro seeCustomWidget
        def contents
          Frame(
            label,
            MarginBox(
              1.45, 0.45,
              RadioButtonGroup(
                Id(:md_level_group),
                VBox(*buttons)
              )
            )
          )
        end

        # @macro seeAbstractWidget
        def init
          self.value = controller.md_level.to_sym
        end

        # @macro seeCustomWidget
        def handle
          controller.md_level = Y2Storage::MdLevel.find(value)
          @devices_widget.refresh_sizes
          nil
        end

        def items
          [
            # TRANSLATORS: 'Striping' is a technical term here. Translate only
            # if you are sure!! If in doubt, leave it in English.
            [:raid0, _("RAID &0  (Striping)")],
            # TRANSLATORS: 'Mirroring' is a technical term here. Translate only
            # if you are sure!! If in doubt, leave it in English.
            [:raid1, _("RAID &1  (Mirroring)")],
            # TRANSLATORS: 'Redundant Striping' is a technical term here. Translate
            # only if you are sure!! If in doubt, leave it in English.
            [:raid5, _("RAID &5  (Redundant Striping)")],
            # TRANSLATORS: 'Dual Redundant Striping' is a technical term here.
            # Translate only if you are sure!! If in doubt, leave it in English.
            [:raid6, _("RAID &6  (Dual Redundant Striping)")],
            # TRANSLATORS: 'Mirroring' and `Striping` are technical terms here.
            # Translate only if you are sure!! If in doubt, leave it in English.
            [:raid10, _("RAID &10  (Mirroring and Striping)")]
          ]
        end

      private

        attr_reader :controller

        # Items for the RadioButtonGroup
        def buttons
          items.map do |item|
            Left(RadioButton(Id(item.first), Opt(:notify), item.last))
          end
        end

        def label
          _("RAID Type")
        end
      end

      # Widget for MD array name
      class NameEntry < CWM::InputField
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        # @macro seeAbstractWidget
        def opt
          [:notify]
        end

        def label
          _("Raid &Name (optional)")
        end

        # @macro seeAbstractWidget
        def init
          self.value = controller.md_name.to_s
        end

        # @macro seeAbstractWidget
        def handle
          controller.md_name = value
          nil
        end

      private

        attr_reader :controller
      end

      # Widget making possible to add and remove partitions to the RAID
      class DevicesSelection < Widgets::DevicesSelection
        def initialize(controller)
          @controller = controller
          super()
        end

        # @see Widgets::DevicesSelection#selected
        def selected
          controller.devices_in_md
        end

        # @see Widgets::DevicesSelection#selected_size
        def selected_size
          controller.md_size
        end

        # @see Widgets::DevicesSelection#unselected
        def unselected
          controller.available_devices
        end

        # @see Widgets::DevicesSelection#select
        def select(sids)
          find_devices(sids, unselected).each do |device|
            controller.add_device(device)
          end
        end

        # @see Widgets::DevicesSelection#select
        def unselect(sids)
          find_devices(sids, selected).each do |device|
            controller.remove_device(device)
          end
        end

        # Validates the number of devices.
        #
        # In fact, the devices are added and removed immediately as soon as
        # the user interacts with the widget, so this validation is only used to
        # prevent the user from reaching the next step in the wizard if the MD
        # array is not valid, not to prevent the information to be stored in
        # the Md object.
        #
        # @macro seeAbstractWidget
        def validate
          return true if controller.devices_in_md.size >= controller.min_devices

          error_args = { raid_level: controller.md_level.to_human_string, min: controller.min_devices }
          Yast::Popup.Error(
            # TRANSLATORS: raid_level is a RAID level (e.g. RAID10); min is a number
            _("For %{raid_level}, select at least %{min} devices.") % error_args
          )
          false
        end

      private

        attr_reader :controller

        def find_devices(sids, list)
          sids.map do |sid|
            list.find { |dev| dev.sid == sid }
          end.compact
        end
      end
    end
  end
end
