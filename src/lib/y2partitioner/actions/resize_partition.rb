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
        @resize_info = partition.detect_resize_info
        UIState.instance.select_row(partition)
      end

      # Checks whether it is possible to resize the partition, and if so,
      # the action is performed.
      #
      # @note An error popup is shown when the partition cannot be resized.
      #
      # @return [Symbol, nil]
      def run
        return :back unless validate
        resize
      end

    private

      # @return [Y2Storage::Partition] partition to resize
      attr_reader :partition

      # @return [Y2Storage::ResizeInfo]
      attr_reader :resize_info

      # Runs the dialog to resize the partition
      #
      # @return [Symbol] :finish if the dialog returns :next; dialog result otherwise.
      def resize
        result = Dialogs::PartitionResize.run(partition, resize_info)
        fix_end_alignment(resize_info)

        result == :next ? :finish : result
      end

      # Checks whether the resize action can be performed
      #
      # @see Y2Storage::ResizeInfo#resize_ok?
      #
      # @return [Boolean] true if the resize action can be performed; false otherwise.
      def validate
        return true if resize_info.resize_ok?

        # TODO: Distinguish the reason why it is not possible to resize, for example:
        # * partition used by commited LVM or MD RAID
        # * extended partition with committed logical partitions

        Yast::Popup.Error(
          # TRANSLATORS: an error popup message
          _("This partition cannot be resized.")
        )

        false
      end

      # After the partition's size was changed during resizing, make sure the
      # new size meets all alignment requirements, but is still between
      # min_size and max_size. This may change the partition's size (and
      # region).
      #
      # @param resize_info [ResizeInfo]
      def fix_end_alignment(resize_info)
        return if @partition.nil?

        ptable = @partition.disk.partition_table
        return @partition.region.size unless ptable.require_end_alignment?

        region = ptable.alignment.align(@partition.region, AlignPolicy::KEEP_END)
        min_blocks = (resize_info.min_size / region.block_size).to_i
        max_blocks = (resize_info.max_size / region.block_size).to_i
        grain_blocks = (ptable.align_grain / region.block_size).to_i

        @partition.region = fix_region_end(region, min_blocks, max_blocks, grain_blocks)
      end

      # Make sure a region's end is between min_blocks and max_blocks. If it
      # is not, add or subtract blocks in grain_blocks increments. All sizes
      # are specified in that region's block size.
      #
      # @param region [Y2Storage::Region]
      # @param min [Fixnum]
      # @param max [Fixnum]
      # @param grain [Fixnum]
      #
      # @return [Y2Storage::Region] adjusted region
      def fix_region_end(region, min, max, grain)
        if region.length < min
          region.adjust_length(grain * ((min.to_f - region.length) / grain).ceil)
        elsif region.length > max
          region.adjust_length(grain * ((max.to_f - region.length) / grain).floor)
        end
        region
      end
    end
  end
end
