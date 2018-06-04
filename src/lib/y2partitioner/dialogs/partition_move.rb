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

      # @return [Symbol] :forward, :backward, :both
      attr_reader :possible_movement

      # @return [Symbol] :forward, :backward
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
        when :backward
          # TRANSLATORS: %{name} is replaced by a partition name (e.g. /dev/sda1)
          VBox(Label(format(_("Move partition %{name} backward?"), name: partition.name)))
        when :forward
          # TRANSLATORS: %{name} is replaced by a partition name (e.g. /dev/sda1)
          VBox(Label(format(_("Move partition %{name} forward?"), name: partition.name)))
        end
      end

    private

      # Only shows ok and cancel buttons (help is excluded)
      def buttons
        [ok_button, cancel_button]
      end

      # Widget to select in which direction to move the partition when it is possible to
      # move forward and backward
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
            ["forward", _("Forward")],
            ["backward", _("Backward")]
          ]
        end

        def init
          self.value = "forward"
        end

        def store
          dialog.selected_movement = value.to_sym
        end
      end
    end
  end
end
