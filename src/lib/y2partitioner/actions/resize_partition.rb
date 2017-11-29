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
require "yast/i18n"
require "y2partitioner/dialogs/partition_resize"
require "y2partitioner/ui_state"

Yast.import "Popup"

module Y2Partitioner
  module Actions
    # Action for resizing a partition
    class ResizePartition
      include Yast::I18n

      # Constructor
      #
      # @param partition [Y2Storage::Partition]
      def initialize(partition)
        textdomain "storage"

        @partition = partition
        UIState.instance.select_row(partition)
      end

      # Checks whether it is possible to resize the partition, and if so,
      # the action is performed.
      #
      # @note An error popup is shown then the partition cannot be resized.
      #
      # @return [Symbol, nil]
      def run
        return :back unless validate
        resize
      end

    private

      # @return [Y2Storage::Partition] partition to resize
      attr_reader :partition

      # Runs the dialog to resize the partition
      #
      # @return [Symbol] :finish if the dialog returns :next; dialog result otherwise.
      def resize
        result = Dialogs::PartitionResize.run(partition)
        # TODO: align the size
        result == :next ? :finish : result
      end

      # Validations before performing the resize action
      #
      # @return [Boolean] true if the resize action can be performed; false otherwise.
      def validate
        not_extended_validation &&
          not_used_validation &&
          formatted_validation
      end

      # Checks whether the partition is not extended
      #
      # @note An error popup is shown if the partition is extended.
      #
      # @return [Boolean] true is the partition is not extended; false otherwise.
      def not_extended_validation
        return true unless partition.type.is?(:extended)

        Yast::Popup.Error(
          # TRANSLATORS: an error popup message
          _("An extended partition cannot be resized.")
        )

        false
      end

      # Checks whether the partition is not used by LVM or MD RAID
      #
      # @note An error popup is shown if the partition is in use.
      #
      # @return [Boolean] true is the partition is in use; false otherwise.
      def not_used_validation
        return true unless partition.descendants.any? { |d| d.is?(:lvm_pv, :md) }

        Yast::Popup.Error(
          format(
            # TRANSLATORS: an error popup message, where %{name} is the name of
            # a partition (e.g., /dev/sda1)
            _("The partition %{name} is in use. It cannot be\n"\
              "resized. To resize %{name}, make sure it is not used."),
            name: partition.name
          )
        )

        false
      end

      # Checks whether the partition is formatted
      #
      # @note An error popup is shown if the partition is not formatted.
      #
      # @return [Boolean] true is the partition is formatted; false otherwise.
      def formatted_validation
        return true if partition.formatted?

        Yast::Popup.Error(
          # TRANSLATORS: an error popup message
          _("Resize not supported by underlying device.")
        )

        false
      end
    end
  end
end
