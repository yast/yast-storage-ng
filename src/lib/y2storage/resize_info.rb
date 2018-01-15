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
  # Information about the possibility of resizing a given device
  #
  # This class is not aimed to represent every possible set of conditions
  # or circumstances. As a result, although some devices (like LVM PVs on-disk)
  # can be shrunk with limitations (see pvresize), their ResizeInfo reports them
  # as if shrinking is not possible.
  #
  # This is a wrapper for Storage::ResizeInfo
  class ResizeInfo
    include StorageClassWrapper
    wrap_class Storage::ResizeInfo

    # @!method resize_ok?
    #   @return [Boolean] whether is possible to resize the device
    storage_forward :resize_ok?, to: :resize_ok

    # @!method min_size
    #   Minimal size the device can be resized to
    #
    #   Note this is not aligned.
    #
    #   @return [DiskSize]
    storage_forward :min_size, as: "DiskSize"

    # @!method max_size
    #   Maximum size the device can be resized to
    #
    #   Note this is not aligned.
    #
    #   @return [DiskSize]
    storage_forward :max_size, as: "DiskSize"
  end
end
