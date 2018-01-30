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
require "y2storage/comparable_by_name"

module Y2Storage
  # A Volume Group of the Logical Volume Manager (LVM)
  #
  # This is a wrapper for Storage::LvmVg
  class LvmVg < Device
    wrap_class Storage::LvmVg

    include ComparableByName

    # @!attribute vg_name
    #   @return [String] volume group name (e.g."vg0"), not to be confused
    #     with BlkDevice#name (e.g. "/dev/mapper/vg0")
    storage_forward :vg_name
    storage_forward :vg_name=

    # @!method size
    #   @return [DiskSize]
    storage_forward :size, as: "DiskSize"

    # @!attribute extent_size
    #   Size of one extent
    #
    #   Each logical volume is split into chunks of data, known as logical
    #   extents. The extent size is the same for all logical volumes in the
    #   volume group.
    #
    #   Setting the extent_size can modify the size of the logical volumes.
    #
    #   @raise Storage::InvalidExtentSize
    #
    #   @return [DiskSize]
    storage_forward :extent_size, as: "DiskSize"
    storage_forward :extent_size=

    # @!method number_of_extents
    #   Total number of extents
    #   @see #extent_size
    #
    #   @return [Integer] total number of extents
    storage_forward :number_of_extents

    # @!method number_of_used_extents
    #   Total number of extents currently in use. May be larger than the number
    #   of extents in the volume group.
    #   @see #extent_size
    #
    #   @return [Integer]
    storage_forward :number_of_used_extents

    # @!method number_of_free_extents
    #   Total number of available extents
    #   @see #extent_size
    #
    #   @return [Integer]
    storage_forward :number_of_free_extents

    # @!method lvm_pvs
    #   @return [Array<LvmPv>] physical volumes in the VG
    storage_forward :lvm_pvs, as: "LvmPv"

    # @!method add_lvm_pv(blk_device)
    #   Adds a block device as a physical volume to the volume group. If there
    #   is not a physical volume on the block device it will be created.
    #
    #   @param blk_device [BlkDevice]
    #   @return [LvmPv]
    storage_forward :add_lvm_pv, as: "LvmPv"

    # @!method remove_lvm_pv(blk_device)
    #   Removes a block device from the volume group. The physical volume on the
    #   block device will the deleted.
    #
    #   @param blk_device [BlkDevice]
    storage_forward :remove_lvm_pv

    # @!method lvm_lvs
    #   Returns the logical volumes in the VG, in no particular order.
    #
    #   @note Thin volumes are actually created over a thin pool volume. This method
    #     includes all thin pools but not their thin volumes.
    #
    #   @return [Array<LvmLv>]
    storage_forward :lvm_lvs, as: "LvmLv"

    # @!method create_lvm_lv(lv_name, lv_type, size)
    #   Creates a logical volume with name lv_name and type lv_type in the volume group.
    #
    #   @param lv_name [String] name of the new volume (see {LvmLv#lv_name})
    #   @param lv_type [LvType] type of the new volume
    #   @param size [DiskSize] size of the new volume
    #   @return [LvmLv]
    storage_forward :create_lvm_lv, as: "LvmLv"

    # @!method delete_lvm_lv(lvm_lv)
    #   Deletes a logical volume in the volume group. Also deletes all
    #   descendants of the logical volume.
    #
    #   @param lvm_lv [LvmLv] volume to delete
    storage_forward :delete_lvm_lv

    # @!method max_size_for_lvm_lv(lv_type)
    #   Returns the max size for a new logical volume of type lv_type. The size may
    #   be limited by other parameters  (e.g. the filesystem on it). The max size also
    #   depends on parameters like the chunk size for thin pools.
    #
    #   @param lv_type [LvType]
    #   @return [DiskSize]
    storage_forward :max_size_for_lvm_lv, as: "DiskSize"

    # @!method overcommitted?
    #   Checks whether the volume group is overcommitted. If it is, Storage#commit
    #   will most likely fail.
    #
    #   @return [Boolean]
    storage_forward :overcommitted?

    # @!method self.create(devicegraph, vg_name)
    #   @param devicegraph [Devicegraph]
    #   @param vg_name [String] See {#vg_name}
    #   @return [LvmVg]
    storage_class_forward :create, as: "LvmVg"

    # @!method self.all(devicegraph)
    #   @param devicegraph [Devicegraph]
    #   @return [Array<LvmVg>] all the volume groups in the given devicegraph,
    #     sorted by #vg_name
    storage_class_forward :all, as: "LvmVg"

    # @!method self.find_by_vg_name(devicegraph, vg_name)
    #   @param devicegraph [Devicegraph]
    #   @param vg_name [String] name of the volume group. See {#vg_name}
    #   @return [LvmVg] nil if there is no such volume group
    storage_class_forward :find_by_vg_name, as: "LvmVg"

    # Determines the available space on the volume group
    #
    # @return [DiskSize] Available space in the volume group
    def available_space
      extent_size * number_of_free_extents
    end

    # Determines the total size of the volume group
    #
    # @return [DiskSize] Size of the volume group
    def total_size
      extent_size * number_of_extents
    end

    # mimics BlkDevice API. Gets name as "/dev/#{vg_name}.
    # @return [String]
    def name
      "/dev/#{vg_name}"
    end

    # Returns all logical volumes in the volume group,
    # including thin volumes (see #lvm_lvs)
    #
    # @return [Array<LvmLv>]
    def all_lvm_lvs
      lvm_lvs.reduce([]) do |lvs, lv|
        lvs << lv
        lvs.concat(lv.lvm_lvs)
      end
    end

    # Returns all thin pools in the volume group
    #
    # @return [Array<LvmLv>]
    def thin_pool_lvm_lvs
      lvm_lvs.select { |l| l.lv_type.is?(:thin_pool) }
    end

    # Returns all thin volumes in the volume group
    #
    # @return [Array<LvmLv>]
    def thin_lvm_lvs
      thin_pool_lvm_lvs.map(&:lvm_lvs).flatten
    end

    alias_method :basename, :vg_name

    # @see Device#potential_orphans
    #
    # @return [Array<Device>]
    def potential_orphans
      lvm_pvs
    end

  protected

    def types_for_is
      super << :lvm_vg
    end
  end
end
