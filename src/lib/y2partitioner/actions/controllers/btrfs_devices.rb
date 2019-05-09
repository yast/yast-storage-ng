# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
      # Controller class to deal with all stuff related to adding or removing devices to
      # a Btrfs filesystem
      class BtrfsDevices
        include Yast::I18n

        include AvailableDevices

        # @return [Y2Storage::Filesystems::Btrfs]
        attr_reader :filesystem

        # @return [String]
        attr_reader :wizard_title

        # Constructor
        #
        # If the filesystem is not given, then a new one is created when the first device is selected.
        #
        # @param filesystem [Y2Storage::Filesystems::Btrfs]
        # @param wizard_title [String]
        def initialize(filesystem: nil, wizard_title: "")
          textdomain "storage"

          @filesystem = filesystem
          @wizard_title = wizard_title

          @metadata_raid_level = Y2Storage::BtrfsRaidLevel::DEFAULT
          @data_raid_level = Y2Storage::BtrfsRaidLevel::DEFAULT

          UIState.instance.select_row(filesystem) if filesystem
        end

        # Metadata RAID level for the filesystem
        #
        # @return [Y2Storage::BtrfsRaidLevel]
        def metadata_raid_level
          raid_level(:metadata)
        end

        # Data RAID level for the filesystem
        #
        # @return [Y2Storage::BtrfsRaidLevel]
        def data_raid_level
          raid_level(:data)
        end

        # Sets the metadata RAID level for the filesystem
        #
        # @param value [Y2Storage::BtrfsRaidLevel]
        def metadata_raid_level=(value)
          save_raid_level(:metadata, value)
        end

        # Sets the data RAID level for the filesystem
        #
        # @param value [Y2Storage::BtrfsRaidLevel]
        def data_raid_level=(value)
          save_raid_level(:data, value)
        end

        # All possible RAID levels
        #
        # Btrfs requires a minimum number of devices for some RAID levels
        #
        # @return [Array<Y2Storage::BtrfsRaidLevel>]
        def raid_levels
          [
            Y2Storage::BtrfsRaidLevel::DEFAULT,
            Y2Storage::BtrfsRaidLevel::SINGLE,
            Y2Storage::BtrfsRaidLevel::DUP,
            Y2Storage::BtrfsRaidLevel::RAID0,
            Y2Storage::BtrfsRaidLevel::RAID1,
            Y2Storage::BtrfsRaidLevel::RAID10
          ]
        end

        # Allowed RAID levels depending on the selected devices
        #
        # @param data [:metadata, :data]
        # @return [Array<Y2Storage::BtrfsRaidLevel>]
        def allowed_raid_levels(data)
          raid_levels = [Y2Storage::BtrfsRaidLevel::DEFAULT]

          raid_levels += filesystem.send("allowed_#{data}_raid_levels")

          raid_levels - forbidden_raid_levels
        end

        # Devices that can be selected for being used by the Btrfs
        #
        # @see AvailableDevices
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def available_devices
          super(current_graph) { |d| valid_device?(d) }
        end

        # Devices used by the Btrfs
        #
        # @return [Array<Y2Storage::BlkDevice>]
        def selected_devices
          return [] unless filesystem

          filesystem.plain_blk_devices
        end

        # Adds a device to the Btrfs
        #
        # If the filesystem does not exist, a new one is created when adding the first device.
        #
        # Any previous children (like filesystems) are removed from the device (only encryption layer
        # is preserved).
        #
        # @param device [Y2Storage::BlkDevice]
        def add_device(device)
          # When the selected device is a partition, its partition id is set to linux.
          device.id = Y2Storage::PartitionId::LINUX if device.is?(:partition)

          device = device.encryption if device.encrypted?

          device.remove_descendants

          if filesystem.nil?
            create_filesystem(device)
          else
            filesystem.add_device(device)
          end
        end

        # Removes a device from the Btrfs
        #
        # @param device [Y2Storage::BlkDevice]
        def remove_device(device)
          device = device.encryption if device.encrypted?
          filesystem.remove_device(device)
          BlkDeviceRestorer.new(device.plain_device).restore_from_checkpoint
        end

      private

        # Helper method to get the RAID level (metadata or data)
        #
        # @param data [:metadata, :data]
        # @return [Y2Storage::BtrfsRaidLevel]
        def raid_level(data)
          # When the filesystem does not exist yet, the value is taken from the class attribute.
          # Otherwise, the filesystem value is taken.
          return instance_variable_get("@#{data}_raid_level") unless filesystem

          filesystem.send("#{data}_raid_level")
        end

        # Helper method to set the RAID level (metadata or data)
        #
        # @param data [:metadata, :data]
        # @param value [Y2Storage::BtrfsRaidLevel]
        def save_raid_level(data, value)
          if filesystem
            filesystem.send("#{data}_raid_level=", value)
          else
            instance_variable_set("@#{data}_raid_level", value)
          end
        end

        # Forbidden RAID levels
        #
        # RAID5 and RAID6 are not offered because Btrfs does not fully support them.
        #
        # @return [Array<Y2Storage::BtrfsRaidLevel>]
        def forbidden_raid_levels
          [Y2Storage::BtrfsRaidLevel::RAID5, Y2Storage::BtrfsRaidLevel::RAID6]
        end

        # Whether the available device is valid for being used by the Btrfs
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def valid_device?(device)
          !device.is?(:encryption) && !selected_device?(device)
        end

        # Whether the device is already selected for being used by the Btrfs
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Boolean]
        def selected_device?(device)
          selected_devices.include?(device)
        end

        # Creates a Btrfs filesystem over the given device
        #
        # @param device [Y2Storage::BlkDevice]
        # @return [Y2Storage::Filesystems::Btrfs]
        def create_filesystem(device)
          filesystem = device.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
          filesystem.metadata_raid_level = @metadata_raid_level
          filesystem.data_raid_level = @data_raid_level

          UIState.instance.select_row(filesystem)

          @filesystem = filesystem
        end

        # Current devicegraph
        #
        # @return [Y2Storage::Devicegraph]
        def current_graph
          DeviceGraphs.instance.current
        end
      end
    end
  end
end
