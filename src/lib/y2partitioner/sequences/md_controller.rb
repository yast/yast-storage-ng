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
require "y2storage"
require "y2partitioner/device_graphs"

module Y2Partitioner
  module Sequences
    # This class stores information about an MD RAID being created and takes
    # care of updating the devicegraph when needed, so the different dialogs
    # can always work directly on a real Md object in the devicegraph.
    class MdController
      include Yast::I18n
      extend Forwardable

      def_delegators :md, :md_level, :md_level=, :md_name,
        :chunk_size, :chunk_size=, :md_parity, :md_parity=

      # @return [Y2Storage::Md] device being created
      attr_reader :md

      # Constructor
      #
      # @note This will create a new Md object in the devicegraph right away.
      def initialize
        textdomain "storage"
        name = Y2Storage::Md.find_free_numeric_name(working_graph)
        @md = Y2Storage::Md.create(working_graph, name)
        @md.md_level = Y2Storage::MdLevel::RAID0 if @md.md_level.is?(:unknown)
        @initial_name = @md.name
      end

      # Partitions that can be selected to become part of the MD array
      #
      # @return [Array<Y2Storage::Partition>]
      def available_devices
        working_graph.partitions.select { |part| available?(part) }
      end

      # Partitions that are already part of the MD array
      #
      # @return [Array<Y2Storage::Partition>]
      def devices_in_md
        md.plain_devices
      end

      # Adds a device to the Md array
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

        # TODO: save the current status and descendants of the device,
        # in case the device is removed from the RAID during this execution of
        # the partitioner.
        device.adapted_id = Y2Storage::PartitionId::RAID if device.is?(:partition)
        device.remove_descendants
        md.add_device(device)
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

        # TODO: restore status and descendants of the device when it makes sense
        md.remove_device(device)
      end

      # Effective size of the resulting Md device
      #
      # @return [Y2Storage::DiskSize]
      def md_size
        md.size
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
      # @return [String]
      def wizard_title
        # TRANSLATORS: dialog title. %s is a device name like /dev/md0
        _("Add RAID %s") % md.name
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
      # @note Parity algorithm only makes sense for Raid5, Raid6 and Raid10.
      #
      # @return [Boolean]
      def parity_supported?
        [:raid5, :raid6, :raid10].include?(md.md_level.to_sym)
      end

    private

      def working_graph
        DeviceGraphs.instance.current
      end

      def available?(partition)
        return false unless partition.id.is?(:linux_system)
        return false if partition.lvm_pv
        return false if partition.md
        return true if partition.filesystem.nil?

        mount = partition.filesystem.mountpoint
        mount.nil? || mount.empty?
      end

      def default_chunk_size
        case md.md_level.to_sym
        when :raid0
          Y2Storage::DiskSize.KiB(32)
        when :raid1
          Y2Storage::DiskSize.KiB(4)
        when :raid5, :raid6
          Y2Storage::DiskSize.KiB(128)
        when :raid10
          Y2Storage::DiskSize.KiB(32)
        else
          Y2Storage::DiskSize.KiB(4)
        end
      end

      def default_md_parity
        Y2Storage::MdParity.find(:default)
      end
    end
  end
end
