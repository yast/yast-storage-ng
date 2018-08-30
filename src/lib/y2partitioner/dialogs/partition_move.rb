# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2partitioner/dialogs/popup"

module Y2Partitioner
  module Dialogs
    # Dialog for moving a partition
    class PartitionMove < Popup
      # @return [Y2Storage::Partition]
      attr_reader :partition

      # @return [Symbol] :beginning, :end, :both
      attr_reader :possible_movement

      # @return [Symbol] :beginning, :end
      attr_accessor :selected_movement

      # Constructor
      #
      # @param partition [Y2Storage::Partition]
      # @param possible_movement [Symbol]
      def initialize(partition, possible_movement)
        textdomain "storage"

        @partition = partition
        @possible_movement = possible_movement
        @selected_movement = possible_movement
      end

      # Layout is different to the default Popup layout
      #
      # This dialog is pretty similar to a basic popup (Yast2::Popup), but in this case it
      # could contain a widget to select the movement direction (beginning or end).
      def layout
        VBox(
          MarginBox(
            2,
            0.4,
            ReplacePoint(Id(:contents), Empty())
          ),
          VSpacing(1),
          ButtonBox(*buttons)
        )
      end

      def contents
        case possible_movement
        when :both
          VBox(DirectionSelector.new(self))
        when :beginning
          # TRANSLATORS: %{name} is replaced by a partition name (e.g. /dev/sda1)
          VBox(Label(format(_("Move partition %{name} towards the beginning?"), name: partition.name)))
        when :end
          # TRANSLATORS: %{name} is replaced by a partition name (e.g. /dev/sda1)
          VBox(Label(format(_("Move partition %{name} towards the end?"), name: partition.name)))
        end
      end

    private

      # Only shows ok and cancel buttons
      #
      # This dialog has not help button in old Partitioner.
      def buttons
        [ok_button, cancel_button]
      end

      # Widget to select in which direction to move the partition when it is possible to
      # move towards the beginning and the end
      class DirectionSelector < CWM::RadioButtons
        # @return [Y2Storage::Partition]
        attr_reader :partition

        # @return [Y2Partitioner::Dialogs::PartitionMove]
        attr_reader :dialog

        # Constructor
        #
        # @param dialog [Y2Partitioner::Dialogs::PartitionMove]
        def initialize(dialog)
          textdomain "storage"

          @dialog = dialog
          @partition = dialog.partition
        end

        def label
          # TRANSLATORS: %{name} is replaced by a partition name (e.g. /dev/sda1)
          format(_("Move partition %{name}?"), name: partition.name)
        end

        def items
          [
            ["beginning", _("Towards the beginning")],
            ["end", _("Towards the end")]
          ]
        end

        def init
          self.value = "beginning"
        end

        # CWM::RadioButtons expects string as item id, but the selected item is stored
        # as symbol into the dialog attribute.
        def store
          dialog.selected_movement = value.to_sym
        end
      end
    end
  end
end
