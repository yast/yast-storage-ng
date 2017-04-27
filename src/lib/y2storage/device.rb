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
  # This is a wrapper for Storage::Device.
  class Device
    include StorageClassWrapper
    wrap_class Storage::Device,
      downcast_to: ["BlkDevice", "Mountable", "PartitionTables::Base", "LvmPv", "LvmVg"]

    # @!method ==(device)
    #   Compare two devices.
    #   @note Devices are equal if they have the same {#sid storage id}.
    #   @see sid
    #
    #   @param device [Device]
    #   @return [Boolean]
    storage_forward :==
    storage_forward :!=

    # @!method sid
    #   @note This value is unique by device.
    #
    #   @return [Fixnum] internal storage id.
    storage_forward :sid

    # @see ancestors
    storage_forward :storage_ancestors, to: :ancestors, as: "Device"
    protected :storage_ancestors

    # @see descendants
    storage_forward :storage_descendants, to: :descendants, as: "Device"
    protected :storage_descendants

    # @see siblings
    storage_forward :storage_siblings, to: :siblings, as: "Device"
    protected :storage_siblings

    # @!method has_children?
    #   Check whether the device has children in the devicegraph
    #   it belongs to.
    #
    #   @return [Boolean]
    storage_forward :has_children?, to: :has_children

    # @!method num_children
    #   Number of children the device has in the devicegraph
    #   it belogs to.
    #
    #   @return [Fixnum]
    storage_forward :num_children

    # @!method exists_in_devicegraph?(devicegraph)
    #   Check whether a devicegraph contains a device with the same sid.
    #   @see sid
    #
    #   @param devicegraph [Devicegraph]
    #   @return [Boolean]
    storage_forward :exists_in_devicegraph?

    # @!method exists_in_probed?
    #   Check whether the device exists in the probed devicegraph.
    #   @see exists_in_devicegraph?
    #
    #   @return [Boolean]
    storage_forward :exists_in_probed?

    # @!method exists_in_staging?
    #   Check whether the device exists in the staging devicegraph.
    #   @see exists_in_devicegraph?
    #
    #   @return [Boolean]
    storage_forward :exists_in_staging?

    # @!method detect_resize_info
    #   Information about the possibility of resizing a given device.
    #   @note Each subclass defines it.
    #   @see ResizeInfo
    #
    #   @return [ResizeInfo]
    storage_forward :detect_resize_info, as: "ResizeInfo"

    # @!method remove_descendants
    #   Remove device descendants in the devicegraph it belongs to.
    storage_forward :remove_descendants

    # Ancestors in the devicegraph in no particular order, not including the
    # device itself.
    #
    # @note This is slightly different from Storage::Device#ancestors, which
    #   requires an argument to decide if the device itself should be included in
    #   the result.
    #
    # @return [Array<Device>]
    def ancestors
      itself = false
      storage_ancestors(itself)
    end

    # Descendants in the devicegraph in no particular order, not including the
    # device itself.
    #
    # @note This is slightly different from Storage::Device#descendants, which
    #   requires an argument to decide if the device itself should be included in
    #   the result.
    #
    # @return [Array<Device>]
    def descendants
      itself = false
      storage_descendants(itself)
    end

    # Siblings in the devicegraph in no particular order, not including the
    # device itself.
    #
    # @note This is slightly different from Storage::Device#siblings, which
    #   requires an argument to decide if the device itself should be included in
    #   the result.
    #
    # @return [Array<Device>]
    def siblings
      itself = false
      storage_siblings(itself)
    end

    # Checks whether the device is a concrete kind(s) of device.
    #
    # @note Always false for this base class, which represents an abstract device.
    #   To be redefined by classes representing more concrete devices.
    #
    #   The goal of this method is to provide a more convenient alternative to the
    #   usage of Object#is_a? that doesn't rely on fully qualified class names and
    #   that can be extended or customized by each device subclass. See examples.
    #
    # @example Checking if a device is a disk
    #
    #   encryption.blk_device.is?(:disk)
    #
    # @example Filtering disks and partitions
    #
    #   something.ancestors.select { |dev| dev.is?(:disk, "partition") }
    #
    # @param types [#to_sym] name (or names) of the device type, as defined in
    #   each subclass.
    # @return [Boolean]
    def is?(*types)
      (types.map(&:to_sym) & types_for_is).any?
    end

  protected

    def types_for_is
      []
    end
  end
end
