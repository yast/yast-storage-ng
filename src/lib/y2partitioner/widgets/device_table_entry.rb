# Copyright (c) [2020] SUSE LLC
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

module Y2Partitioner
  module Widgets
    # Class to represent each entry of a table of devices, including the device
    # itself and all the corresponding nested entries (like the partitions of a
    # given disk).
    #
    # For example, a table containing two disks with several partitions each would
    # have two top-level DeviceTableEntry objects, each of them containing the
    # corresponding partitions as nested ({#children}) DeviceTableEntry objects.
    class DeviceTableEntry
      # Device represented in this entry
      # @return [Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry]
      attr_accessor :device

      # Nested entries
      #
      # @return [Array<DeviceTableEntry>]
      attr_reader :children

      # Whether the device should be represented in the table using the full name
      #
      # When this is false, the device may be represented with the full name or
      # with a short version, depending on the circumstances.
      #
      # @return [Boolean] true to enforce the usage of full name
      def full_name?
        !!@full_name
      end

      # Constructor
      #
      # @param device [Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry] see #device
      # @param children [Array<Y2Storage::Device, DeviceTableEntry>] for children
      #   specified as a device, a {DeviceTableEntry} will be created honoring full_names
      # @param full_names [Boolean] If true, #full_name? will be enforced for this entry
      #   and also for all the children entries without an existing DeviceTableEntry
      def initialize(device, children: [], full_names: false)
        @device = device
        @full_name = full_names

        @children = children.map do |child|
          if child.is_a?(DeviceTableEntry)
            child
          else
            DeviceTableEntry.new(child, full_names: full_names)
          end
        end
      end

      # Device identifier of the referenced device, if any
      #
      # @return [Integer, nil] nil if the device is not part of the devicegraph
      #   (ie. it's a {Y2Storage::SimpleEtcFstabEntry})
      def sid
        return nil unless device.respond_to?(:sid)

        device.sid
      end

      # LibYUI id of the table row
      #
      # @return [String] row id for given device
      def row_id
        "table:device:#{id}"
      end

      # CWM table item to represent this entry in the table
      #
      # @return [CWM::TableItem]
      def table_item(cols)
        values = cols.map { |c| c.entry_value(self) }
        sub_items = children.map { |c| c.table_item(cols) }

        CWM::TableItem.new(row_id, values, children: sub_items)
      end

      # Collection including this entry and all its descendants
      #
      # @return [Array<DeviceTableEntry>]
      def all_entries
        @all_entries ||= [self] + children.flat_map(&:all_entries)
      end

      # Collection including the devices referenced by this entry and by all its
      # descendant entries
      #
      # @return [Array<Y2Storage::Device, Y2Storage::SimpleEtcFstabEntry>]
      def all_devices
        all_entries.map(&:device)
      end

      protected

      # Identifier for the entry
      #
      # @return [Integer]
      def id
        # Y2Storage::SimpleEtcFstabEntry does not respond to #sid method
        sid || device.object_id
      end

      class << self
        # Creates an entry for the given device with the expected descendant
        # entries based on the type and content of the device
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [DeviceTableEntry]
        def new_with_children(device)
          children =
            if device.is?(:lvm_vg)
              # All logical volumes, including thin pools and thin volumes
              device.all_lvm_lvs
            elsif device.respond_to?(:partitions)
              # All partitions, with logical ones nested within the extended
              nested_partitions(device)
            else
              []
            end

          new(device, children: children)
        end

        # Partitions of the given device, with logical partitions nested within
        # the extended one
        #
        # @see .new_with_children
        #
        # @return [Array<Y2Storage::Partition, DeviceTableEntry>] the extended partition
        #   is returned as a DeviceTableEntry with logical ones as children
        def nested_partitions(device)
          device.partitions.each_with_object([]) do |partition, children|
            next if partition.type.is?(:logical)

            children <<
              if partition.type.is?(:primary)
                partition
              else
                new(partition, children: partition.children)
              end
          end
        end
      end
    end
  end
end
