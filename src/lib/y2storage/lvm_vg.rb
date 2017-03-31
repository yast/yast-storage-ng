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
  # A Volume Group of the Logical Volume Manager (LVM)
  #
  # This is a wrapper for Storage::LvmVg
  class LvmVg < Device
    wrap_class Storage::LvmVg

    # Volume group name. This is different from the device name
    storage_forward :vg_name
    storage_forward :vg_name=

    storage_forward :size, as: "DiskSize"
    storage_forward :extent_size, as: "DiskSize"
    storage_forward :extent_size=

    storage_forward :number_of_extents
    storage_forward :number_of_used_extents
    storage_forward :number_of_free_extents

    storage_forward :lvm_pvs, as: "LvmPv"
    storage_forward :add_lvm_pv, as: "LvmPv"
    storage_forward :remove_lvm_pv, as: "LvmPv"

    storage_forward :lvm_lvs, as: "LvmLv"
    storage_forward :create_lvm_lv, as: "LvmLv"
    storage_forward :delete_lvm_lv, as: "LvmLv"

    storage_class_forward :create, as: "LvmVg"
    storage_class_forward :all, as: "LvmVg"
    storage_class_forward :find_by_vg_name, as: "LvmVg"

    # @see Device#is?
    #
    # In this case, true if type is or contains :lvm_vg
    def is?(types)
      super || types_include?(types, :lvm_vg)
    end
  end
end
