require "yast"
require "cwm/dialog"
require "cwm/common_widgets"
require "y2partitioner/widgets/devices_selection"

module Y2Partitioner
  module Dialogs
    # Determine the type, name and devices of a RAID to
    # be created or modified.
    # Part of {Sequences::AddMd}.
    class Md < CWM::Dialog
      def initialize(controller)
        textdomain "storage"
        @controller = controller
        @level         = LevelChoice.new(controller)
        @name          = NameEntry.new(controller)
        @dev_selection = DevicesSelection.new(controller)
      end

      # @macro seeDialog
      def title
        # TRANSLATORS: dialog title. %s is a device name like /dev/md0
        _("Add RAID %s") % controller.md.name
      end

      # @macro seeDialog
      def contents
        res = VBox(
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

      class LevelChoice < CWM::CustomWidget
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        def value
          Yast::UI.QueryWidget(Id(:md_level_group), :Value)
        end

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

        def init
          val = controller.md.md_level
          val = val.is?(:unknown) ? :raid0 : val.to_sym
          Yast::UI.ChangeWidget(Id(:md_level_group), :Value, val)
        end

        def store
          controller.md.md_level = Y2Storage::MdLevel.find(value)
        end

      private
        attr_reader :controller

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

        def label
          _("RAID Type")
        end

        def buttons
          items.map do |item|
            Left(RadioButton(Id(item.first), item.last))
          end
        end
      end

      class NameEntry < CWM::InputField
        def initialize(controller)
          textdomain "storage"
          @controller = controller
        end

        def label
          _("Raid &Name (optional)")
        end

        def init
          self.value = md.md_name.to_s
        end

        def store
          md.md_name = value unless value.empty?
        end

      private

        attr_reader :controller

        def md
          controller.md
        end
      end

      class DevicesSelection < Widgets::DevicesSelection
        def initialize(controller)
          @controller = controller
          unselected = controller.available_devices
          selected = md.plain_devices
          super(unselected, selected)
        end

        def store
          controller.devices = selected
        end

      private

        attr_reader :controller

        def md
          controller.md
        end
      end
    end
  end
end
