# encoding: utf-8

# Copyright (c) [2017-2019] SUSE LLC
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
require "y2storage"
require "y2partitioner/device_graphs"
require "y2partitioner/ui_state"
require "y2partitioner/blk_device_restorer"
require "y2partitioner/actions/controllers/available_devices"

module Y2Partitioner
  module Actions
    module Controllers
      # This class stores information about an MD RAID being created or modified
      # and takes care of updating the devicegraph when needed, so the different
      # dialogs can always work directly on a real Md object in the devicegraph.
      class Md
        include Yast::I18n

        include AvailableDevices

        extend Forwardable

        def_delegators :md, :md_level, :md_level=, :md_name,
          :chunk_size, :chunk_size=, :md_parity, :md_parity=

        # Constructor
        #
        # @note When the device is not given, a new Md object will be created in
        #   the devicegraph right away.
        #
        # @param md [Y2Storage::Md] a MD RAID to work on
        def initialize(md: nil)
          textdomain "storage"

          # A MD RAID is given to modify its used devices
          @action = md.nil? ? :add : :edit_devices

          md ||= new_md

          @md_sid = md.sid
          @initial_name = md.name
          UIState.instance.select_row(md)
        end

        # MD RAID being modified
        #
        # @return [Y2Storage::Md]
        def md
          working_graph.find_device(@md_sid)
        end

        # Devices that can be selected to become part of the MD array
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def available_devices
          devices = super(working_graph) { |d| valid_device?(d) }

          devices.sort { |a, b| a.compare_by_name(b) }
        end

        # Partitions that are already part of the MD array, sorted by position
        #
        # @return [Array<Y2Storage::Partition>]
        def devices_in_md
          md.sorted_plain_devices
        end

        # Adds a device at the end of the Md array
        #
        # It removes any previous children (like filesystems) from the device and
        # adapts the partition id if possible.
        #
        # @raise [ArgumentError] if the device is already in the RAID
        #
        # @param device [Y2Storage::BlkDevice]
        def add_device(device)
          if md.devices.include?(device)
            raise ArgumentError, "The device #{device} is already part of the Md #{md}"
          end

          # When adding a whole disk (or other partitionable device) we need to
          # ensure the partition table will be not affected (i.e. restored) if
          # the users change their mind during the process.
          BlkDeviceRestorer.new(device).update_checkpoint if device.respond_to?(:partition_table)

          device.adapted_id = Y2Storage::PartitionId::RAID if device.is?(:partition)
          device.remove_descendants
          md.push_device(device)
        end

        # Removes a device from the Md array
        #
        # @raise [ArgumentError] if the device is not in the RAID
        #
        # @param device [Y2Storage::BlkDevice]
        def remove_device(device)
          if !md.devices.include?(device)
            raise ArgumentError, "The device #{device} is not part of the Md #{md}"
          end

          md.remove_device(device)
          BlkDeviceRestorer.new(device).restore_from_checkpoint
        end

        # Modifies the position of some devices in the MD RAID, moving them one
        # step up (before in the list) or down (later in the list)
        #
        # @param sids [Array<Integer>] sids of the devices to move. They all must
        #   be part of {#devices_in_md}
        # @param up [Symbol] true to move devices up, false to move them down
        def devices_one_step(sids, up: true)
          devices = md.sorted_devices
          to_move = indexes_of_devices(sids, devices)
          new_order = move_indexes(to_move, devices.size, up)

          md.sorted_devices = new_order.map { |idx| devices[idx] }
        end

        # Modifies the position of some devices in the MD RAID, moving them to
        # the beginning of the list.
        #
        # @param sids [Array<Integer>] sids of the devices to move. They all must
        #   be part of {#devices_in_md}
        def devices_to_top(sids)
          selected, others = md.sorted_devices.partition { |dev| sids.include?(dev.plain_device.sid) }
          md.sorted_devices = selected + others
        end

        # Modifies the position of some devices in the MD RAID, moving them to
        # the end of the list.
        #
        # @param sids [Array<Integer>] sids of the devices to move. They all must
        #   be part of {#devices_in_md}
        def devices_to_bottom(sids)
          selected, others = md.sorted_devices.partition { |dev| sids.include?(dev.plain_device.sid) }
          md.sorted_devices = others + selected
        end

        # Effective size of the resulting Md device
        #
        # @return [Y2Storage::DiskSize]
        def md_size
          md.size
        end

        # Allowed partity algorithms
        #
        # Allowed parities depends on the RAID type and the number of devices in the Md RAID
        #
        # @return [Array<Y2Storage::MdParity>]
        def md_parities
          md.allowed_md_parities
        end

        # Sets the name of the Md device
        #
        # Unlike {Y2Storage::Md#md_name=}, setting the value to nil or empty will
        # effectively turn the Md device back into a numeric one.
        #
        # @param name [String, nil]
        def md_name=(name)
          if name.nil? || name.empty?
            md.name = @initial_name
          else
            md.md_name = name
          end
        end

        # Title to display in the dialogs during the process
        #
        # @note The returned title depends on the action to perform (see {#initialize})
        #
        # @return [String]
        def wizard_title
          case @action
          when :add
            # TRANSLATORS: dialog title when creating a MD RAID.
            # %s is a device name like /dev/md0
            _("Add RAID %s") % md.name
          when :edit_devices
            # TRANSLATORS: dialog title when editing the devices of a Software RAID.
            # %s is a device name (e.g., /dev/md0)
            _("Edit devices of RAID %s") % md.name
          end
        end

        # Sets default values for the chunk size and parity algorithm of the Md device
        #
        # @note Md level must be previously set.
        # @see #default_chunk_size
        # @see #default_md_parity
        def apply_default_options
          md.chunk_size = default_chunk_size
          md.md_parity = default_md_parity if parity_supported?
        end

        # Whether is possible to set the parity configuration for the current Md device
        #
        # @note Parity algorithm only makes sense for Raid5, Raid6 and Raid10, see
        #   {Y2Storage::Md#allowed_md_parities}
        #
        # @return [Boolean]
        def parity_supported?
          md.allowed_md_parities.any?
        end

        # Minimal number of devices required for the Md object.
        #
        # @see Y2Storage::Md#minimal_number_of_devices
        #
        # @return [Integer]
        def min_devices
          md.minimal_number_of_devices
        end

        # Possible chunk sizes for the Md object depending on its md_level.
        #
        # @return [Array<Y2Storage::DiskSize>]
        def chunk_sizes
          sizes = []
          size = min_chunk_size

          while size <= max_chunk_size
            sizes << Y2Storage::DiskSize.new(size)
            size *= 2
          end
          sizes
        end

      private

        def working_graph
          DeviceGraphs.instance.current
        end

        # Creates a new MD RAID
        #
        # @return [Y2Storage::Md]
        def new_md
          name = Y2Storage::Md.find_free_numeric_name(working_graph)
          md = Y2Storage::Md.create(working_graph, name)
          md.md_level = Y2Storage::MdLevel::RAID0 if md.md_level.is?(:unknown)
          md
        end

        # Whether an available device is valid to be used in a MD RAID
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def valid_device?(device)
          if device.is?(:partition)
            valid_partition_for_md?(device)
          else
            valid_device_for_md?(device)
          end
        end

        # Whether an available partition is valid to be used in a MD RAID
        #
        # The partition can be used if its id is linux, lvm, swap or raid, and it is not created over a
        # RAID.
        #
        # The reasons to filter RAID partitions out (basically possible complications with booting and/or
        # auto-assembling) are explained in doc/sle15_features_in_partitioner.md.
        #
        # @param partition [Y2Storage::Partition]
        # @return [Boolean]
        def valid_partition_for_md?(partition)
          partition.id.is?(:linux_system) && !partition.partitionable.is?(:raid)
        end

        # Whether an available device is valid to be used in a MD RAID
        #
        # The device can be used if its has a proper type.
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def valid_device_for_md?(device)
          # StrayBlkDevice are not offered. They are used for very concrete
          # use cases in which RAID makes probably no sense.
          device.is?(:disk, :multipath)
        end

        def min_chunk_size
          [default_chunk_size, Y2Storage::DiskSize.KiB(64)].min
        end

        def max_chunk_size
          Y2Storage::DiskSize.MiB(64)
        end

        def default_chunk_size
          case md.md_level.to_sym
          when :raid0
            Y2Storage::DiskSize.KiB(64)
          when :raid1
            Y2Storage::DiskSize.KiB(4)
          when :raid5, :raid6
            Y2Storage::DiskSize.KiB(128)
          when :raid10
            Y2Storage::DiskSize.KiB(64)
          else
            Y2Storage::DiskSize.KiB(64)
          end
        end

        def default_md_parity
          Y2Storage::MdParity.find(:default)
        end

        # Indexes of the given sids within a full list of devices
        #
        # It locates devices by its sid or by the sid of its plain device
        # (useful if some encrypted devices that are part of the MD).
        def indexes_of_devices(sids, list)
          sids.map { |sid| list.index { |dev| dev.plain_device.sid == sid } }.compact
        end

        def move_indexes(idxs_to_move, list_size, up)
          indexes = Array(0..(list_size - 1))
          # When moving down, we must iterate the list in inverse order for the
          # algorithm to work.
          indexes.reverse! unless up

          consecutive = 0
          indexes.sort_by do |idx|
            if idxs_to_move.include?(idx)
              # This logic is better explained with an example. Let's say we want
              # the third, fourth and fifth devices in the list to go up and, thus,
              # be placed before the current second one. These will be the results:
              #
              #   third  -> 0.9   (reduced enough to be before 1)
              #   fourth -> 0.99  (extra decimal, stable sorting among the moving devices)
              #   fifth  -> 0.999 (same here)
              #   second -> 1     (original index, the other branch of the 'if')
              consecutive += 1
              delta = consecutive + 0.1**consecutive
              up ? idx - delta : idx + delta
            else
              consecutive = 0
              idx
            end
          end
        end
      end
    end
  end
end
