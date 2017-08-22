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
require "y2storage/storage_class_wrapper"
require "yaml"

module Y2Storage
  # An abstract base class of storage devices and a vertex in the Devicegraph.
  #
  # The Device class does not have a device name since some device types do
  # not have a intrinsic device name, e.g. btrfs.
  #
  # This is a wrapper for Storage::Device.
  class Device
    include Yast::Logger
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
    #   @return [Integer] internal storage id.
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

    # @!method parents
    #   Parents in the devicegraph in no particular order.
    #   @return [Array<Device>]
    storage_forward :parents, as: "Device"

    # @!method has_children?
    #   Check whether the device has children in the devicegraph
    #   it belongs to.
    #
    #   @return [Boolean]
    storage_forward :has_children?, to: :has_children

    # @!method num_children
    #   Number of children the device has in the devicegraph
    #   it belongs to.
    #
    #   @return [Integer]
    storage_forward :num_children

    # @!method exists_in_devicegraph?(devicegraph)
    #   Check whether a devicegraph contains a device with the same
    #   {#sid storage id}.
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

    # @!method storage_detect_resize_info
    #   @abstract Each subclass defines it.
    #   @see detect_resize_info
    storage_forward :storage_detect_resize_info, to: :detect_resize_info, as: "ResizeInfo"
    protected :storage_detect_resize_info

    # @!method remove_descendants
    #   Remove device descendants in the devicegraph it belongs to.
    storage_forward :remove_descendants

    # @!attribute userdata
    #   Collection of free-form text fields to be stored in the devicegraph
    #   alongside the device. Useful for users of the library to add their own
    #   status information.
    #
    #   @return [Storage::MapStringString]
    storage_forward :userdata
    storage_forward :userdata=
    protected :userdata, :userdata=

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

    # @!method detect_resize_info
    #   Information about the possibility of resizing a given device. Returns
    #   nil if the device does not exist in the probed devicegraph.
    #   @see ResizeInfo
    #   @see exists_in_probed?
    #   @note This is slightly different from Storage::detect_resize_info, which
    #     requires to be called in a device that belongs to the probed devicegraph.
    #
    #   @return [ResizeInfo]
    def detect_resize_info
      return nil unless exists_in_probed?
      probed_device = StorageManager.instance.probed.find_device(sid)
      probed_device.storage_detect_resize_info
    end

    # Checks whether the device is a concrete kind(s) of device.
    #
    # Always false for this base class, which represents an abstract device.
    # To be redefined by classes representing more concrete devices.
    #
    # The goal of this method is to provide a more convenient alternative to the
    # usage of Object#is_a? that doesn't rely on fully qualified class names and
    # that can be extended or customized by each device subclass. See examples.
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

    # Stores any object in the userdata of the device.
    #
    # This method takes care of serializing the information to make sure it fits
    # into the userdata mechanism.
    # @see #userdata
    #
    # @param key [#to_s] name of the information in the userdata container
    # @param value [Object] information to store
    def save_userdata(key, value)
      userdata[key.to_s] = value.to_yaml
    end

    # Returns a copy of any information previously stored in the device using
    # {#save_userdata}.
    #
    # This method takes care of deserializing the stored information.
    #
    # Take into account that the result is just a copy of the information, so
    # changes in the object will not be persisted to the userdata.
    # #{save_userdata} must be used to update the information in the device if
    # needed.
    #
    # @example Updating a value
    #
    #   save_userdata(:aliases, ["dev_one", "dev_two"])
    #
    #   userdata_value(:aliases).concat "dev_three"
    #   userdata_value(:aliases) # => ["dev_one", "dev_two"]
    #
    #   tmp = userdata_value(:aliases)
    #   tmp.concat "dev_three"
    #   save_userdata(:aliases, tmp)
    #   userdata_value(:aliases) # => ["dev_one", "dev_two", "dev_three"]
    #
    # @param key [#to_s] name of the information in the userdata container
    # @return [Object] a copy of the previously stored object
    def userdata_value(key)
      serialized = userdata[key.to_s]
      return nil if serialized.nil?
      YAML.load(serialized)
    end

    def types_for_is
      []
    end
  end
end
