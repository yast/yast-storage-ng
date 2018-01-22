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

module Y2Storage
  # A logical volume of the Logical Volume Manager (LVM)
  #
  # This is a wrapper for Storage::LvmLv
  class LvmLv < BlkDevice
    wrap_class Storage::LvmLv

    # @!method lv_name
    #   @return [String] logical volume name (e.g. "lv1"), not to be confused
    #     with BlkDevice#name (e.g. "/dev/mapper/vg0/lv1")
    storage_forward :lv_name

    # @!method lvm_vg
    #   @return [LvmVg] volume group the LV belongs to
    storage_forward :lvm_vg, as: "LvmVg"

    # @!attribute stripes
    #   Number of stripes. 0 if the LV is not striped
    #   @return [Integer]
    storage_forward :stripes
    storage_forward :stripes=

    # @!attribute stripe_size
    #   Size of a stripe. DiskSize.zero if the LV is not striped.
    #   @return [DiskSize]
    storage_forward :stripe_size, as: "DiskSize"
    storage_forward :stripe_size=

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<Disk>] all the logical volumes in the given devicegraph
    storage_class_forward :all, as: "LvmLv"

    # Resizes the volume, taking resizing limits and extent size into account.
    #
    # It does nothing if resizing is not possible (see {ResizeInfo#resize_ok?}).
    # Otherwise, it sets the size of the LV based on the requested size.
    #
    # If the requested size is out of the min/max limits provided by
    # {#resize_info}, the end will be adjusted to the corresponding limit.
    #
    # If the requested size is between the limits, the size will be set to the
    # closest valid (i.e. divisible by the extent size) value, rounding down if
    # needed.
    #
    # @param new_size [DiskSize] temptative new size of the volume, take into
    #   account that the result may be slightly smaller after rounding it down
    #   based on the extent size
    def resize(new_size)
      log.info "Trying to resize #{name} (#{size}) to #{new_size}"
      return unless can_resize?

      # The sizes in resize_info are already rounded to the extent size
      self.size =
        if new_size > resize_info.max_size
          resize_info.max_size
        elsif new_size < resize_info.min_size
          resize_info.min_size
        else
          new_size
        end
      log.info "Size of #{name} set to #{size}"
    end

  protected

    def types_for_is
      super << :lvm_lv
    end
  end
end
