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
require "yast/i18n"
require "yast2/popup"
require "y2partitioner/dialogs/partition_move"
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"
require "y2partitioner/exceptions"

module Y2Partitioner
  module Actions
    # Action for moving a partition
    #
    # To move a partition means to place it at the beginning or at the end of the
    # previous or next adjacent free space, respectively.
    class MovePartition
      include Yast::I18n

      # Constructor
      #
      # @param partition [Y2Storage::BlkDevice]
      def initialize(partition)
        textdomain "storage"

        @partition = partition
        UIState.instance.select_row(partition.sid)
      end

      # Checks whether it is possible to move the partition, and if so, the action is performed.
      #
      # @note An error popup is shown when the partition cannot be moved. In case the partition
      #   can be moved, a dialog is presented to select whether to move forward or backward.
      #
      # @return [Symbol] :finish if the action is performed; :back or dialog result otherwise.
      def run
        return :back unless validate

        answer = move_partition_question
        return answer unless answer == :ok

        move_partition
        :finish
      end

    private

      # @return [Y2Storage::BlkDevice]
      attr_reader :partition

      # @return [Symbol] :forward, :backward
      attr_reader :movement

      # Checks whether the partition can be moved
      #
      # @note When the partition cannot be moved, it shows a popup with the reason,
      #   see {#error}.
      #
      # @return [Boolean] true if the partition can be moved; false otherwise.
      def validate
        return true unless error

        Yast2::Popup.show(error, headline: :error)
        false
      end

      # Why the partition cannot be moved
      #
      # @note A partition can be moved if is not an extended partition and it does
      #   not exist on disk and there is adjancent free space where to move it. In
      #   some cases, the move action could be called over a device that is not a
      #   partition (i.e., when the selected element on a table is not a partition).
      #   For that reason, the type of the device must be checked.
      #
      # @return [String, nil] nil when there is no error and the partition can be moved.
      def error
        device_type_error ||
          extended_partition_error ||
          existing_partition_error ||
          no_space_error
      end

      # Error when a no partition device is tried to be moved
      #
      # @return [String, nil] nil the device is a partition
      def device_type_error
        return nil if partition.is?(:partition)

        # FIXME: This message is copied from old partitioner, but it could be improved.
        _("Hard disks, BIOS RAIDs and multipath\n" \
          "devices cannot be moved.")
      end

      # Error when a extended partition is tried to be moved
      #
      # @return [String, nil] nil when the partition is not extended
      def extended_partition_error
        return nil unless partition.type.is?(:extended)

        _("An extended partition cannot be moved.")
      end

      # Error when an existing partition is tried to be moved
      #
      # @return [String, nil] nil if the partition does not exist on disk
      def existing_partition_error
        return nil unless partition.exists_in_devicegraph?(DeviceGraphs.instance.system)

        # FIXME: This message is copied from old partitioner, but it could be improved.
        format(
          # TRANSLATORS: error message where %{name} is replaced by a partition name (e.g. /dev/sda1)
          _("The partition %{name} is already created on disk\n" \
            "and cannot be moved."),
          name: partition.name
        )
      end

      # Error when there is no adjacent free space to move the partition
      #
      # @return [String, nil] nil when there is any adjacent free space
      def no_space_error
        return nil unless possible_movement.nil?

        # FIXME: This message is copied from old partitioner, but it could be improved.

        # TRANSLATORS: error message where %{name} is replaced by a partition name (e.g. /dev/sda1)
        format(_("No space to move partition %{name}"), name: partition.name)
      end

      # Shows a dialog to ask to the user how to move the partition (forward or backward)
      #
      # @note The user selection is saved, see {#movement}.
      #
      # @return [Symbol] dialog result (:ok, :cancel)
      def move_partition_question
        dialog = Dialogs::PartitionMove.new(partition, possible_movement)
        dialog_result = dialog.run

        @movement = dialog.selected_movement
        dialog_result
      end

      # Possible direction in which the partition could be moved
      #
      # @return [Symbol] :forward, :backward, or :both
      def possible_movement
        if previous_adjacent_unused_slot && next_adjacent_unused_slot
          :both
        elsif previous_adjacent_unused_slot
          :forward
        elsif next_adjacent_unused_slot
          :backward
        end
      end

      # Moves the partition to the selected direction
      #
      # @note "Move forward" means to move the partition towards the beginning of the disk.
      #   Otherwise, "move backward" means to move towards the end of the disk.
      #
      # @see #moves_forward, #moves_backward
      def move_partition
        movement == :forward ? move_forward : move_backward
      end

      # Moves the patition by placing it at the beginning of the previous adjacent free space
      #
      # @raise [Y2Partitioner::Error] if there is no previous adjacent free space
      def move_forward
        if !previous_adjacent_unused_slot
          raise Error, "Partition #{partition.name} cannot be moved forward"
        end

        partition.region.start = previous_adjacent_unused_slot.region.start
      end

      # Moves the patition by placing it at the end of the next adjacent free space
      #
      # @raise [Y2Partitioner::Error] if there is no next adjacent free space
      def move_backward
        if !next_adjacent_unused_slot
          raise Error, "Partition #{partition.name} cannot be moved backward"
        end

        partition.region.start += next_adjacent_unused_slot.region.length
      end

      # Previous adjacent free space where the partition can be moved to
      #
      # @return [Y2Storage::PartitionTables::PartitionSlot, nil] nil if there is no previous
      #   adjacent free space.
      def previous_adjacent_unused_slot
        return nil unless previous_unused_slot
        return previous_unused_slot unless previous_partition

        previous_unused_slot.region.start > previous_partition.region.start ? previous_unused_slot : nil
      end

      # Next adjacent free space where the partition can be moved to
      #
      # @return [Y2Storage::PartitionTables::PartitionSlot, nil] nil if there is no next
      #   adjacent free space.
      def next_adjacent_unused_slot
        return nil unless next_unused_slot
        return next_unused_slot unless next_partition

        next_unused_slot.region.start < next_partition.region.start ? next_unused_slot : nil
      end

      # Previous free space, not necessary adjacent to the partition
      #
      # @note In case the partition to move is a primary partition, free spaces inside an extended
      #   partition are not taken into account. Otherwise, when the partition is logical, only free
      #   spaces inside the extended partition are considered.
      #
      # @return [Y2Storage::PartitionTables::PartitionSlot, nil] nil if there is no previous free space.
      def previous_unused_slot
        unused_slots(partition.type).reverse_each.find { |s| s.region.start < partition.region.start }
      end

      # Next free space, not necessary adjacent to the partition
      #
      # @note In case the partition to move is a primary partition, free spaces inside an extended
      #   partition are not taken into account. Otherwise, when the partition is logical, only free
      #   spaces inside the extended partition are considered.
      #
      # @return [Y2Storage::PartitionTables::PartitionSlot, nil] nil if there is no next free space.
      def next_unused_slot
        unused_slots(partition.type).find { |s| s.region.start > partition.region.start }
      end

      # Partition placed before the partition to move
      #
      # @note In case the partition to move is a primary partition, logical partitions are not taken
      #   into account. Otherwise, when the partition is logical, only other logical partitions are
      #   considered.
      #
      # @return [Y2Storage::Partition, nil] nil if there is no partition before.
      def previous_partition
        partitions(partition.type).reverse_each.find { |p| p.region.start < partition.region.start }
      end

      # Partition placed after the partition to move
      #
      # @note In case the partition to move is a primary partition, logical partitions are not taken
      #   into account. Otherwise, when the partition is logical, only other logical partitions are
      #   considered.
      #
      # @return [Y2Storage::Partition, nil] nil if there is no partition after.
      def next_partition
        partitions(partition.type).find { |p| p.region.start > partition.region.start }
      end

      # All free spaces in the partition table of the partition to move.
      #
      # @note When param partition_type is :logical, only free spaces inside an extended partition are
      #   considered. Otherwise, all free spaces inside the extended partition are discarded.
      #
      # @param partition_type [Y2Storage::PartitionType]
      # @return [Array<Y2Storage::PartitionTables::PartitionSlot>]
      def unused_slots(partition_type)
        slots =
          if partition_type.is?(:logical)
            unused_slots_for_logical_partitions
          else
            unused_slots_for_non_logical_partitions
          end

        slots.sort_by { |s| s.region.start }
      end

      # Free spaces inside the extended partition
      #
      # @return [Array<Y2Storage::PartitionTables::PartitionSlot>]
      def unused_slots_for_logical_partitions
        aligned_unused_slots.select { |s| s.possible?(Y2Storage::PartitionType::LOGICAL) }
      end

      # Free spaces excluding space inside the extended partition
      #
      # @return [Array<Y2Storage::PartitionTables::PartitionSlot>]
      def unused_slots_for_non_logical_partitions
        aligned_unused_slots.reject { |s| s.possible?(Y2Storage::PartitionType::LOGICAL) }
      end

      # All free spaces, aligned at both: start and end
      #
      # @note Free spaces are obtained with alignment at start and end to ensure that the moved
      #   partition continues aligned (if it was already start and end aligned). If the partition
      #   was not start and end aligned, the resulting moved partition will not be aligned either.
      #
      #   For example:
      #
      #   * start aligned but end not aligned -> moves forward -> start aligned but end not aligned
      #   * start aligned but end not aligned -> moves backward -> start not aligned but end aligned
      #
      #   * start not aligned but end aligned -> moves forward -> start aligned but end not aligned
      #   * start not aligned but end aligned -> moves backward -> start not aligned but end aligned
      #
      #   * start and end aligned -> moves forward -> start and end aligned
      #   * start and end aligned -> moves backward -> start and end aligned
      #
      # @return [Array<Y2Storage::PartitionTables::PartitionSlot>]
      def aligned_unused_slots
        partition.partition_table.unused_partition_slots(Y2Storage::AlignPolicy::ALIGN_START_AND_END)
      end

      # All partitions in the partition table of the partition to move.
      #
      # @note When param partition_type is :logical, only logical partitions are considered. Otherwise,
      #   all logical partitions are discarded.
      #
      # @param partition_type [Y2Storage::PartitionType]
      # @return [Array<Y2Storage::Partition>]
      def partitions(partition_type)
        partitions =
          if partition_type.is?(:logical)
            logical_partitions
          else
            non_logical_partitions
          end

        partitions.sort_by { |p| p.region.start }
      end

      # All logical partitions in the partition table of the partition to move.
      #
      # @return [Array<Y2Storage::Partition>]
      def logical_partitions
        partition.partition_table.partitions.select { |p| p.type.is?(:logical) }
      end

      # All non logical partitions in the partition table of the partition to move.
      #
      # @return [Array<Y2Storage::Partition>]
      def non_logical_partitions
        partition.partition_table.partitions.reject { |p| p.type.is?(:logical) }
      end
    end
  end
end
