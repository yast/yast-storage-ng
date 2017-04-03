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
require "y2storage/device"

module Y2Storage
  # A physical volume of the Logical Volume Manager (LVM)
  #
  # This is a wrapper for Storage::LvmPv
  class LvmPv < Device
    wrap_class Storage::LvmPv

    storage_class_forward :all, as: "LvmPv"

    storage_forward :lvm_vg, as: "LvmVg"

    # @!method blk_device
    #   Block device directly hosting the PV. That is, for encrypted PVs it
    #   returns the encryption device.
    #
    #   @return [BlkDevice]
    storage_forward :blk_device, as: "BlkDevice"

    # Raw (non encrypted) version of the device hosting the PV.
    #
    # If the PV is not encrypted, this is equivalent to #blk_device, otherwise
    # it returns the original device instead of the encryption one.
    #
    # @return [BlkDevice]
    def plain_blk_device
      blk_device.plain_device
    end

  protected

    def types_for_is
      super << :lvm_pv
    end
  end
end
