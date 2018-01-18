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
require "y2storage"
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about a future partition so that information
      # can be shared across the different dialogs of the process. It also takes
      # care of updating the devicegraph when needed.
      class Partition
        include Yast::I18n

        # @return [Y2Storage::PartitionType]
        attr_accessor :type

        # @return [:max_size,:custom_size,:custom_region]
        attr_accessor :size_choice

        # for {#size_choice} == :custom_size
        # @return [Y2Storage::DiskSize]
        attr_accessor :custom_size

        # for any {#size_choice} value this ends up with a valid value
        # @return [Y2Storage::Region]
        attr_accessor :region

        # New partition created by the controller.
        #
        # Nil if #create_partition has not beeing called or if the partition was
        # removed with #delete_partition.
        #
        # @return [Y2Storage::Partition, nil]
        attr_reader :partition

        # Name of the device being partitioned
        # @return [String]
        attr_reader :disk_name

        def initialize(disk_name)
          textdomain "storage"

          @disk_name = disk_name
        end

        # Device being partitioned
        # @return [Y2Storage::BlkDevice]
        def disk
          dg = DeviceGraphs.instance.current
          Y2Storage::BlkDevice.find_by_name(dg, disk_name)
        end

        # Available slots to create the partition in which the start is aligned
        # according to AlignType::OPTIMAL (the end is not aligned)
        #
        # @see unused_slots
        #
        # @return [Array<Y2Storage::PartitionTables::PartitionSlot>]
        def unused_optimal_slots
          # Caching seems to be important for the current dialogs to work
          @unused_optimal_slots ||= disk.ensure_partition_table.unused_partition_slots
        end

        # All available slots to create the partition, honoring just the
        # required alignment
        #
        # @see optimal_unused_slots
        #
        # @return [Array<Y2Storage::PartitionTables::PartitionSlot>]
        def unused_slots
          # Caching seems to be important for the current dialogs to work
          @unused_slots ||= disk.ensure_partition_table.unused_partition_slots(
            Y2Storage::AlignPolicy::KEEP_END, Y2Storage::AlignType::REQUIRED
          )
        end

        # Grain to use in order to keep the optimal alignment
        #
        # @return [Y2Storage::DiskSize]
        def optimal_grain
          disk.ensure_partition_table.align_grain
        end

        # Grain to use in order to keep the required alignment
        #
        # @return [Y2Storage::DiskSize]
        def required_grain
          disk.ensure_partition_table.align_grain(Y2Storage::AlignType::REQUIRED)
        end

        # Creates the partition in the disk according to the controller
        # attributes (#type, #region, etc.)
        def create_partition
          ptable = disk.ensure_partition_table
          slot = slot_for(region)
          aligned = align(region, slot, ptable)
          @partition = ptable.create_partition(slot.name, aligned, type)
          UIState.instance.select_row(@partition)
        end

        # Removes the previously created partition from the disk
        def delete_partition
          return if @partition.nil?

          ptable = disk.ensure_partition_table
          ptable.delete_partition(@partition)
          @partition = nil
        end

        # Removes the filesystem when the disk is directly formatted
        def delete_filesystem
          disk.delete_filesystem
        end

        # Whether the disk is in use
        #
        # @note A disk is in use when it is used as physical volume or
        #   belongs to a MD RAID.
        #
        # @return [Boolean]
        def disk_used?
          disk.partition_table.nil? && disk.descendants.any? { |d| d.is?(:lvm_pv, :md) }
        end

        # Whether the disk is formatted
        #
        # @return [Boolean]
        def disk_formatted?
          disk.formatted?
        end

        # Whether is possible to create any new partition in the disk
        #
        # @return [Boolean]
        def new_partition_possible?
          unused_optimal_slots.any?(&:available?)
        end

        # Title to display in the dialogs during the process
        # @return [String]
        def wizard_title
          # TRANSLATORS: dialog title. %s is a device name like /dev/sda
          _("Add Partition on %s") % disk_name
        end

        # Error to display to the user if the blocks selected to define a
        # custom region are not valid.
        #
        # The string, if any, is already internationalized.
        #
        # @return [String, nil] nil if the blocks are valid (no error)
        def error_for_custom_region(start_block, end_block)
          parent = unused_slots.map(&:region).find { |r| r.cover?(start_block) }

          if !parent
            # starting block must be in a region,

            # TRANSLATORS: text for an error popup
            _("The block entered as start is not available.")
          elsif end_block < start_block
            # TRANSLATORS: text for an error popup
            _("The end block cannot be before the start.")
          elsif !parent.cover?(end_block)
            # ending block must be in the same region than the start

            # TRANSLATORS: text for an error popup
            _("The region entered collides with the existing partitions.")
          elsif too_small_custom_region?(start_block, end_block)
            # It's so small that we already know that we can't align both
            # start and end

            # TRANSLATORS: text for an error popup
            _("The region entered is too small, not supported by this device.")
          elsif !alignable_custom_region?(start_block, end_block)
            # Almost pathological case, but still can happen if the user tries
            # to break stuff

            # TRANSLATORS: text for an error popup
            _("Invalid region entered, increase the size or align the start.")
          end
        end

      protected

        # Partition slot containing the given region
        #
        # @param region [Y2Storage::Region] region for the new partition
        # @return [Y2Storage::PartitionTables::PartitionSlot, nil] nil if the
        #   region is not contained in any of the relevant slots
        def slot_for(region)
          slots = align_only_to_required? ? unused_slots : unused_optimal_slots
          slots.find { |slot| region.inside?(slot.region) }
        end

        # Aligns the region that will be used to create a new partition,
        # according to the following partitioner logic:
        #
        #   * If the user specified a size, region.start is already granted to
        #     be aligned according to OPTIMAL and this method:
        #     * Leaves region.end untouched if it's equal to the end of the
        #       slot, because that means the user wants to use the whole space
        #       until the next "barrier" (the end of the disk or the start of an
        #       existing partition) with no gap.
        #     * Aligns region.end to OPTIMAL if it's smaller then the end of the
        #       slot, because that means the user wants to leave some space and
        #       we want that remaining space to start in an optimal block.
        #   * If the user specified a custom region, region.start and region.end
        #     are aligned according only to REQUIRED, not taking the optimal
        #     performance into consideration. In most cases that implies no
        #     changes but in some devices (like DASD) that small alignment makes
        #     the creation possible.
        #
        # @param region [Y2Storage::Region] a region describing the intended
        #   location of the new partition
        # @param slot [Y2Storage::PartitionTables::PartitionSlot] the slot
        #   to be used as base for the partition creation
        # @param ptable [Y2Storage::PartitionTables::Base]
        # @return [Y2Storage::Region] aligned according to the description above
        def align(region, slot, ptable)
          if align_only_to_required?
            ptable.align(
              region, Y2Storage::AlignPolicy::ALIGN_START_AND_END, Y2Storage::AlignType::REQUIRED
            )
          else
            # Let's aim for optimal alignment or for usage of the whole space
            ptable.align_end(region, max_end: slot.region.end)
          end
        rescue Storage::AlignError
          # If something goes wrong during alignment, just try to create the
          # smallest (thus, safer) possible partition with a valid start.
          # Anyway, the validations in the dialog should prevent any possible
          # alignment error, so this should never be reached.
          grain = ptable.align_grain(Y2Storage::AlignType::REQUIRED)
          blk_size = region.block_size.to_i
          Y2Storage::Region.create(slot.region.start, grain.to_i / blk_size, blk_size)
        end

        # Whether the resulting partition should be aligned only to mandatory
        # requirements (Y2Storage::AlignType::REQUIRED) ignoring any performance
        # consideration.
        #
        # @return [Boolean] false if the partition should be aligned for optimal
        #   performance (i.e. honoring Y2Storage::AlignType::OPTIMAL)
        def align_only_to_required?
          # If the user defined a custom region, let's respect it as much as
          # possible, so only the REQUIRED alignment is enforced.
          size_choice == :custom_region
        end

        # @return [Y2Storage::DiskSize]
        def block_size
          unused_slots.first.region.block_size
        end

        # Whether the given custom region can be aligned to hardware
        # requirements without disappearing in the process.
        #
        # @return [Boolean]
        def alignable_custom_region?(start_blk, end_blk)
          region = Y2Storage::Region.create(start_blk, end_blk - start_blk + 1, block_size)
          disk.ensure_partition_table.align(
            region, Y2Storage::AlignPolicy::ALIGN_START_AND_END, Y2Storage::AlignType::REQUIRED
          )
          true
        rescue Storage::AlignError
          false
        end

        # Whether the given custom region is too small to be aligned to hardware
        # requirements.
        #
        # @return [Boolean]
        def too_small_custom_region?(start_blk, end_blk)
          size = block_size * (end_blk - start_blk + 1)
          size < required_grain
        end
      end
    end
  end
end
