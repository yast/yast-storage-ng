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

module Y2Storage
  # An abstract base class of storage devices and a vertex in the Devicegraph.
  #
  # The Device class does not have a device name since some device types do
  # not have a intrinsic device name, e.g. btrfs.
  #
  # This is a wrapper for Storage::Device
  class Device
    include StorageClassWrapper
    wrap_class Storage::Device,
      downcast_to: ["BlkDevice", "Mountable", "PartitionTables::Base"]

    storage_forward :==
    storage_forward :!=
    storage_forward :sid
    storage_forward :ancestors, as: "Device"
    storage_forward :has_children?, to: :has_children
    storage_forward :exists_in_devicegraph?
    storage_forward :exists_in_probed?
    storage_forward :exists_in_staging?
    storage_forward :displayname
    storage_forward :detect_resize_info
    storage_forward :remove_descendants
    storage_forward :userdata
    storage_forward :userdata=
  end
end
