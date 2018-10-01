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
require "cwm/common_widgets"
require "y2partitioner/dialogs/base"
require "y2partitioner/widgets/md_devices_selector"

# Work around YARD inability to link across repos/gems:
# (declaring macros here works because YARD sorts by filename size(!))

# @!macro [new] seeAbstractWidget
#   @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FAbstractWidget:${0}
# @!macro [new] seeCustomWidget
#   @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FCustomWidget:${0}
# @!macro [new] seeDialog
#   @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FDialog:${0}
# @!macro [new] seeItemsSelection
#   @see http://www.rubydoc.info/github/yast/yast-yast2/CWM%2FItemsSelection:${0}

Yast.import "Popup"

module Y2Partitioner
  module Dialogs
    # Form to set the type, name and devices of an MD RAID to be created
    # Part of {Actions::AddMd}.
    class Md < Base
      def initialize(controller)
        textdomain "storage"
        @controller = controller
        @dev_selection = Widgets::MdDevicesSelector.new(controller)
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
        # @param controller [Actions::Controllers::Md]
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

        def help
          # TRANSLATORS: Help text heading
          "<p><b>" + _("RAID Type:") + "</b><ul><li>" +
            [raid0_help,
             raid1_help,
             raid5_help,
             raid6_help,
             raid10_help].join("</li><li>") +
            "</li></ul></p>"
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

        def raid0_help
          _("<b>RAID 0:</b> " \
            "This level increases your disk performance. " \
            "There is <b>NO</b> redundancy in this mode. " \
            "If one of the drives crashes, data recovery will not be possible.")
        end

        def raid1_help
          _("<b>RAID 1:</b> " \
            "This mode has the best redundancy. " \
            "It can be used with two or more disks. " \
            "This mode maintains an exact copy of all data on all disks. " \
            "As long as at least one disk is still working, no data are lost. "  \
            "The partitions used for this type of RAID should have " \
            "approximately the same size.")
        end

        def raid5_help
          _("<b>RAID 5:</b>" \
            "This mode combines management of a larger number of disks " \
            "and still maintains some redundancy. " \
            "This mode can be used on three disks or more. " \
            "If one disk fails, all data are still intact. " \
            "If two disks fail simultaneously, all data are lost.")
        end

        def raid6_help
          _("<b>RAID 6:</b>" \
            "This is similar to RAID 5, but with even more redundancy. " \
            "This requires at least four disks. " \
            "If two out of four disks fail simultaneously, no data are lost.")
        end

        def raid10_help
          _("<b>RAID 10:</b>" \
            "This combines RAID 0 (striping) and RAID 1 (mirroring) " \
            "for improved performance while still maintaining redundancy " \
            "and thus crash recovery.")
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

        def help
          _("<p><b>Raid Name: </b> " \
            "A meaningful name for the RAID. This is optional. " \
            "If a name is provided, the device is available as " \
            "<tt>/dev/md/&lt;name&gt;</tt>." \
            "</p>")
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
    end
  end
end
