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

require "y2storage/storage_class_wrapper"
require "y2storage/blk_device"
require "y2storage/disk"
require "y2storage/align_policy"
require "y2storage/align_type"

module Y2Storage
  # A partition in a partitionable device (like a disk or RAID).
  #
  # This is a wrapper for Storage::Partition.
  class Partition < BlkDevice
    wrap_class Storage::Partition

    # @!method number
    #   Partition number extracted from its name (e.g. 2 for "/dev/sda2").
    #
    #   @raise [Storage::Exception] if name does not contain a number.
    #
    #   @return [Integer]
    storage_forward :number

    # @!method partition_table
    #   @return [PartitionTables::Base] the concrete subclass will depend
    #     on the type
    storage_forward :partition_table, as: "PartitionTables::Base"

    # @!method partitionable
    #   @return [Partitionable] device hosting the partition table.
    storage_forward :partitionable, as: "Partitionable"

    # @!attribute type
    #   {PartitionType Type} of the partition.
    #   @see PartitionType
    #
    #   @return [PartitionType]
    storage_forward :type, as: "PartitionType"
    storage_forward :type=

    # @!attribute id
    #   {PartitionId Id} of the partition.
    #   @see PartitionId
    #   @see #adapted_id= for a safer alternative to set this value
    #
    #   @return [PartitionId]
    storage_forward :id, as: "PartitionId"
    storage_forward :id=

    # @!method boot?
    #   Boot flag of the partition, only supported on Msdos.
    #
    #   @note
    #     1. To be
    #     [standard-conformant](https://en.wikipedia.org/wiki/Master_boot_record),
    #     setting the boot flag on a partition clears the boot flag on all
    #     other partitions of the partition table.
    #
    #     2. Partitions on GPT have no boot flag, "set <nr> boot on" with
    #     parted on GPT partitions only sets the partition type to EFI System
    #     Partition.
    #
    #   @return [Boolean]
    storage_forward :boot?

    # @!method boot=(flag)
    #   Set bot flag of the partition.
    #   @see boot?
    #
    #   @param flag [Boolean]
    storage_forward :boot=

    # @!method legacy_boot?
    #   Legacy boot flag of the partition, only supported on Gpt.
    #
    #   @return [Boolean]
    storage_forward :legacy_boot?

    # @!method legacy_boot=(flag)
    #   Set legacy boot flag of the partition.
    #
    #   @param flag [Boolean]
    storage_forward :legacy_boot=

    # @!method self.create(devicegraph, name, region, type)
    #   To get suitable values for this method, use
    #   {PartitionTables::Base#unused_partition_slots}
    #   @see Region
    #   @see #type
    #
    #   @param devicegraph [Devicegraph]
    #   @param name [String]
    #   @param region [Region]
    #   @param type [PartitionType]
    #   @return [Partition]
    storage_class_forward :create, as: "Partition"

    # @!method self.find_by_name(devicegraph, name)
    #   @param devicegraph [Devicegraph]
    #   @param name [String]
    #   @return [Partition] nil if there is no such partition.
    storage_class_forward :find_by_name, as: "Partition"

    # Disk the partition belongs to or nil if the partition is
    # not over a disk (e.g. a RAID).
    #
    # @return [Disk]
    def disk
      partitionable.is_a?(Disk) ? partitionable : nil
    end

    # Grain for alignment
    #
    # @see PartitionTables::Base#align_grain
    #
    # @param align_type [AlignType, nil]
    # @return [DiskSize]
    def align_grain(align_type = nil)
      partition_table.align_grain(align_type)
    end

    # Whether the first block of the partition is aligned according to
    # the partition table grain.
    #
    # @param align_type [AlignType, nil] see #align_grain
    # @return [Boolean]
    def start_aligned?(align_type = nil)
      region.start_aligned?(align_grain(align_type))
    end

    # Whether the final block of the partition is aligned according to
    # the partition table grain.
    #
    # @param align_type [AlignType, nil] see #align_grain
    # @return [Boolean]
    def end_aligned?(align_type = nil)
      region.end_aligned?(align_grain(align_type))
    end

    # Resizes the partition by moving its end, taking alignment and resizing
    # limits into account.
    #
    # This method never moves the partition start. If possible, the new end
    # will always be aligned.
    #
    # The new end will always be within the min and max provided by
    # #{#resize_info}, even if the requested size is bigger or smaller than
    # those limits or if that means giving up on alignment.
    #
    # It does nothing if resizing is not possible (see {ResizeInfo#resize_ok?}).
    #
    # @param new_size [DiskSize] temptative new size of the partition, take into
    #   account that the result may differ a bit due to alignment or limits
    # @param align_type [AlignType] type of alignment
    def resize(new_size, align_type: AlignType::OPTIMAL)
      log.info "Trying to resize #{name} (#{size}) to #{new_size} (align: #{align_type})"
      return unless can_resize?

      max = resize_info.max_size
      min = resize_info.min_size
      self.size =
        if new_size > max
          max
        elsif new_size < min
          min
        else
          new_size
        end
      log.info "Partition #{name} size initially set to #{size}"

      # NOTE: maybe it also makes sense to skip aligning if the new region ends
      # at the end of the disk
      return if align_type.nil?
      self.region = aligned_region(align_type)
      log.info "Partition #{name} finally adjusted to #{size}"
    end

    # All partitions in the given devicegraph, in no particular order
    #
    # @param devicegraph [Devicegraph]
    # @return [Array<Partition>]
    def self.all(devicegraph)
      Partitionable.all(devicegraph).map(&:partitions).flatten
    end

    # @return [String]
    def inspect
      "<Partition #{name} #{size}, #{region.show_range}>"
    end

    # Sets the id, ensuring its value is compatible with the partition table.
    #
    # In general, use this method instead of #id= if unsure.
    #
    # @see PartitionTables::Base#partition_id_for
    # @see #id
    #
    # @param partition_id [PartitionId]
    def adapted_id=(partition_id)
      self.id = partition_table.partition_id_for(partition_id)
    rescue ::Storage::Exception
      # if we made some mistake, log an error but don't break completely
      fallback_id = PartitionId::LINUX
      log.error "Failed to set partition id #{partition_id}, falling back to #{fallback_id}"
      self.id = fallback_id
    end

  protected

    # Values for volume specification matching
    #
    # @see MatchVolumeSpec
    def volume_match_values
      super.merge(partition_id: id)
    end

    def types_for_is
      super << :partition
    end

    # Region resulting from aligning and applying limits to the current
    # partition region.
    #
    # It may be the original region if a new region couldn't be calculated (i.e.
    # it's not possible to honor alignment and limits at the same time).
    #
    # @see #resize
    #
    # @param align_type [AlignType] type of alignment
    def aligned_region(align_type)
      new_region = align_region_end(region, align_type)
      fix_region_end(new_region, align_type)

      if new_region.size > resize_info.max_size || new_region.size < resize_info.min_size
        region
      else
        new_region
      end
    end

    # Aligns the end of a region, leaving the start untouched.
    #
    # @param region [Region] original region to align
    # @param align_type [AlignType]
    # @return [Region] a copy of region with the same start but the end aligned
    #   according to align_type
    def align_region_end(region, align_type)
      # Currently, there is no way to use PartitionTable#align without
      # enforcing the alignment of the start. Despite what the ALIGN_END name
      # may suggest, that policy alters both start and end. So the following
      # line is not enough to implement this method.
      # partition_table.align(region, AlignPolicy::ALIGN_END, align_type)

      # This could be turned into a simple call to PartitionTable#align in the
      # future if a KEEP_START_ALIGN_END (or similar) policy is provided by
      # libstorage-ng in the future.
      if region.end_aligned?(align_grain(align_type))
        Region.create(region.start, region.length, region.block_size)
      else
        region_end = partition_table.align(region, AlignPolicy::ALIGN_END, align_type).end
        Region.create(region.start, region_end - region.start + 1, region.block_size)
      end
    end

    # Ensures the end of the given region is within the resizing limits of the
    # partition and keeps the same alignment.
    #
    # @note This modifies the region parameter
    #
    # @param region [Region] region to adjust, can be modified
    # @param align_type [AlignType]
    def fix_region_end(region, align_type)
      block_size = region.block_size.to_i
      length     = region.length

      min_blks   = resize_info.min_size.to_i / block_size
      max_blks   = resize_info.max_size.to_i / block_size
      grain_blks = align_grain(align_type).to_i / block_size

      if length < min_blks
        region.adjust_length(grain_blks * ((min_blks.to_f - length) / grain_blks).ceil)
      elsif length > max_blks
        region.adjust_length(grain_blks * ((max_blks.to_f - length) / grain_blks).floor)
      end
    end
  end
end
