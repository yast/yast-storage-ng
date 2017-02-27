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

module Y2Storage

  module ExtraSpaceAssigner

    # Returns a copy of the list in which the given space has been distributed
    # among the volumes, distributing the extra space (beyond the target size)
    # according to the weight and max size of each volume.
    #
    # @raise [RuntimeError] if the given space is not enough to reach the target
    #     size for all volumes
    #
    # If the optional argument rounding is used, space will be distributed
    # always in blocks of the specified size.
    #
    # @param space_size [DiskSize]
    # @param rounding [DiskSize, nil] min block size to distribute. Mainly used
    #     to distribute space among LVs honoring the PE size of the LVM
    # @param min_grain [DiskSize, nil] minimal grain of the disk where the space
    #     is located. It only makes sense when distributing space among
    #     partitions.
    # @return [PlannedVolumesList] list containing volumes with an adjusted
    #     value for PlannedVolume#disk_size
    def distribute_space(proposed_devices, space_size, rounding: nil, min_grain: nil)
      required_size = ProposedLv.disk_size(proposed_devices) 
      raise RuntimeError if space_size < required_size

      rounding ||= min_grain
      rounding ||= DiskSize.new(1)

      proposed_devices.each do |proposed_device| 
        proposed_device.disk_size = proposed_device.disk_size.ceil(rounding)
      end

      adjust_size_to_last_slot!(proposed_devices.last, space_size, min_grain) if min_grain

      extra_size = space_size - total_disk_size(proposed_devices)
      unused = distribute_extra_space!(proposed_devices, extra_size, rounding)
      proposed_devices.last.disk_size += unused if min_grain && unused < min_grain

      proposed_devices
    end

  private
  
    def adjust_size_to_last_slot!(proposed_device, space_size, min_grain)
      adjusted_size = adjusted_size_after_ceil(proposed_device, space_size, min_grain)
      target_size = proposed_device.disk_size
      proposed_device.disk_size = adjusted_size unless adjusted_size < target_size
    end

    def adjusted_size_after_ceil(proposed_device, space_size, min_grain)
      mod = space_size % min_grain
      last_slot_size = mod.zero? ? min_grain : mod
      return proposed_device.disk_size if last_slot_size == min_grain

      missing = min_grain - last_slot_size
      proposed_device.disk_size - missing
    end

    # @return [DiskSize] Surplus space that could not be distributed
    def distribute_extra_space!(proposed_devices, extra_size, rounding)
      candidates = proposed_devices
      while distributable?(extra_size, rounding)
        candidates = extra_space_candidates(candidates)
        return extra_size if candidates.empty?
        return extra_size if total_weight(candidates).zero?
        log.info("Distributing #{extra_size} extra space among #{candidates.size} volumes")

        assigned_size = DiskSize.zero
        total_weight = total_weight(candidates)
        candidates.each do |proposed_device|
          device_extra = proposed_device_extra_size(proposed_device, extra_size, total_weight, assigned_size, rounding)
          proposed_device.disk_size += device_extra
          log.info("Distributing #{device_extra} to #{proposed_device.mount_point}; now #{proposed_device.disk_size}")
          assigned_size += device_extra
        end
        extra_size -= assigned_size
      end
      log.info("Could not distribute #{extra_size}") unless extra_size.zero?
      extra_size
    end

    # Volumes that may grow when distributing the extra space
    #
    # @param volumes [PlannedVolumesList] initial set of all volumes
    # @return [PlannedVolumesList]
    def extra_space_candidates(proposed_devices)
      proposed_devices.select do |proposed_device|
        proposed_device.disk_size < proposed_device.max_disk_size
      end
    end

    def distributable?(size, rounding)
      size >= rounding
    end

    # Extra space to be assigned to a volume
    #
    # @param volume [PlannedVolume] volume to enlarge
    # @param total_size [DiskSize] free space to be distributed among
    #    involved volumes
    # @param total_weight [Float] sum of the weights of all involved volumes
    # @param assigned_size [DiskSize] space already distributed to other volumes
    # @param rounding [DiskSize] size to round up
    #
    # @return [DiskSize]
    def proposed_device_extra_size(proposed_device, total_size, total_weight, assigned_size, rounding)
      available_size = total_size - assigned_size

      extra_size = total_size * (proposed_device.weight / total_weight)
      extra_size = extra_size.ceil(rounding)
      extra_size = available_size.floor(rounding) if extra_size > available_size

      new_size = extra_size + proposed_device.disk_size
      if new_size > proposed_device.max_disk_size
        # Increase just until reaching the max size
        proposed_device.max_disk_size - proposed_device.disk_size
      else
        extra_size
      end
    end

    # Total sum of all current sizes of volumes
    #
    # @return [DiskSize] sum of sizes in @volumes
    def total_disk_size(proposed_devices)
      proposed_devices.reduce(DiskSize.zero) { |sum, device| sum + device.disk_size }
    end

    # Total sum of all weights of volumes
    #
    # @return [Float]
    def total_weight(proposed_devices)
      proposed_devices.reduce(0.0) { |sum, device| sum + device.weight }
    end

  end
end