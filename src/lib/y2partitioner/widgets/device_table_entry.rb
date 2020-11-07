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
require "cwm/table"

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

      # Whether the entry is the parent of the given one
      #
      # @param entry [DeviceTableEntry]
      # @return [Boolean]
      def parent?(entry)
        children.include?(entry)
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
      # @param cols [Array<Columns::Base>] columns to display
      # @param open_items [Hash{String => Boolean}] hash listing whether items
      #   should be expanded or collapsed. See {BlkDevicesTable#open_items}.
      # @return [CWM::TableItem]
      def table_item(cols, open_items)
        values = cols.map { |c| c.entry_value(self) }
        sub_items = children.map { |c| c.table_item(cols, open_items) }
        open = open_items.fetch(row_id, true)

        CWM::TableItem.new(row_id, values, children: sub_items, open: open)
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
        # @param device [Y2Storage::Device]
        # @return [DeviceTableEntry]
        def new_with_children(device)
          items = children(device).map { |c| new_with_children(c) }

          new(device, children: items)
        end

        private

        def children(device)
          return btrfs_subvolumes(device) if nesting_btrfs_subvolumes?(device)

          if device.is?(:lvm_vg)
            # All logical volumes, including thin pools and thin volumes
            device.all_lvm_lvs
          elsif device.respond_to?(:partitions)
            # Logical partitions are not included because they are nested within the extended one
            device.partitions.reject { |p| p.type.is?(:logical) }
          elsif device.is?(:partition) && device.type.is?(:extended)
            # All logical partitions
            device.children
          else
            []
          end
        end

        # Whether the given device should show Btrfs subvolumes as children devices
        #
        # @param device [Y2Storage::Device]
        # @return [Boolean]
        def nesting_btrfs_subvolumes?(device)
          return true if device.is?(:btrfs)

          return false unless device.is?(:blk_device)

          device.formatted_as?(:btrfs) && !device.filesystem.multidevice?
        end

        # Btrfs subvolumes to show as children devices
        #
        # @param device [Y2Storage::Device]
        # @return [Array<Y2Storage::BtrfsSubvolume>]
        def btrfs_subvolumes(device)
          filesystem = device.is?(:filesystem) ? device : device.filesystem

          # FIXME: the default subvolume is not shown, but maybe it should be included when pointing
          #   to something different to @.
          filesystem.btrfs_subvolumes.reject { |s| s.top_level? || s.default_btrfs_subvolume? }
        end
      end
    end
  end
end
