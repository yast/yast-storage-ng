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

require "y2storage"
require "y2storage/proposal/device_shrinkage"
require "forwardable"

module Y2Storage
  module Proposal
    # Result of executing {Proposal::AutoinstDevicesCreator}. This class
    # extends the original {Proposal::CreatorResult} with some AutoYaST related
    # information.
    #
    # @see CreatorResult
    class AutoinstCreatorResult
      extend Forwardable

      def_delegators :@creator_result, :created_names, :devices_map, :devicegraph

      # @return [Array<Planned::Device>] List of originally planned devices
      attr_reader :planned_devices

      # Constructor
      #
      # @param creator_result  [CreatorResult] Original creator result object
      # @param planned_devices [Array<Planned::Device>] Planned devices
      def initialize(creator_result, planned_devices)
        @creator_result = creator_result
        @planned_devices = planned_devices
      end

      # Return a list containing information about shrinked partitions
      #
      # @see DeviceShrinkage
      def shrinked_partitions
        @shrinked_partitions ||= shrinked_devices(planned_partitions)
      end

      # Return a list containing information about shrinked logical volumes
      #
      # @see DeviceShrinkage
      def shrinked_lvs
        @shrinked_lvs ||= shrinked_devices(planned_lvs)
      end

      # Calculate how much space is missing
      #
      # @return [DiskSize]
      def missing_space
        meth = shrinked_partitions.empty? ? :shrinked_lvs : :shrinked_partitions
        diffs = public_send(meth).map(&:diff)
        Y2Storage::DiskSize.sum(diffs)
      end

      # Using the planned_id of a planned device, find the corresponding one in the devicegraph
      #
      # @param planned_id [String] Planned device planned_id
      def real_device_by_planned_id(planned_id)
        name, _planned = devices_map.find { |_n, d| d.planned_id == planned_id }
        return nil unless name
        Y2Storage::BlkDevice.find_by_name(devicegraph, name)
      end

    private

      # Planned logical volumes
      #
      # @return [Array<Y2Storage::Planned::LvmLv>] Logical volumes
      def planned_lvs
        return @planned_lvs if @planned_lvs
        vgs = planned_devices.select { |d| d.is_a?(Planned::LvmVg) }
        @planned_lvs = vgs.map(&:lvs).flatten
      end

      # Planned partitions
      #
      # @return [Array<Y2Storage::Planned::Partition>] Partitions
      def planned_partitions
        @planned_partitions ||= planned_devices.select { |d| d.is_a?(Planned::Partition) }
      end

      # Return a list of DeviceShrinkage objects for a given collection
      #
      # Any device which has not been shrinked will be filtered out.
      #
      # @param collection [Array<Y2Storage::Planned::Partition>,Array<Y2Storage::Planned::LvmLv>]
      # @return [Array<Y2Storage::DeviceShrinkage>]
      def shrinked_devices(collection)
        collection.each_with_object([]) do |device, all|
          real_device = real_device_by_planned_id(device.planned_id)
          next if real_device.nil? || real_device.size.to_i >= device.min_size.to_i
          all << DeviceShrinkage.new(device, real_device)
        end
      end
    end
  end
end
