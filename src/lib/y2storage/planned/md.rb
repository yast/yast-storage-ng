#!/usr/bin/env ruby
#
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
require "y2storage/planned/device"
require "y2storage/planned/mixins"

module Y2Storage
  module Planned
    # Specification for a Y2Storage::Md object to be created during the
    # AutoYaST proposal
    #
    # @see Device
    class Md < Device
      include Planned::CanBeFormatted
      include Planned::CanBeMounted
      include Planned::CanBeEncrypted
      include Planned::CanBePv

      # @return [name] device name of the MD RAID
      attr_accessor :name

      # @return [DiskSize] see {Y2Storage::Md#chunk_size}
      attr_accessor :chunk_size

      # @return [MdParity] see {Y2Storage::Md#md_parity}
      attr_accessor :md_parity

      # @return [MdLevel] see {Y2Storage::Md#md_level}
      attr_accessor :md_level

      # Forced order in which the devices should be added to the final MD RAID.
      #   @see #add_devices
      #   @return [Array<String>] sorted list of device names
      attr_accessor :devices_order

      # Constructor.
      #
      def initialize(name: nil)
        initialize_can_be_formatted
        initialize_can_be_mounted
        initialize_can_be_encrypted
        initialize_can_be_pv
        @name = name
      end

      # Adds the provided block devices to the existing MD array
      #
      # @see Y2Storage::Md#devices
      #
      # The block devices will be added to the array in the order specified by
      # {#devices_order}. If #{devices_order} is nil or empty, the devices will
      # be added in alphabetical order (AutoYaST documented behavior).
      #
      # @param devices [Array<Y2Storage::BlkDevice>] block devices to add
      # @param md_device [Y2Storage::Md] MD device created to represent this
      #   planned device. It will be modified.
      def add_devices(devices, md_device)
        sorted =
          if devices_order.nil? || devices_order.empty?
            devices.sort_by(&:name)
          else
            devices.sort_by { |d| devices_order.index(d.name) }
          end

        sorted.each do |device|
          md_device.add_device(device)
        end
      end

      def self.to_string_attrs
        [:mount_point, :reuse, :name, :lvm_volume_group_name, :subvolumes]
      end
    end
  end
end
