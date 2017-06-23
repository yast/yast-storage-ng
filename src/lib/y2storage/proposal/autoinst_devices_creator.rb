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

require "y2storage/proposal/partitions_distribution_calculator"
# TODO: fix distribution calculator to don't require this
require "y2storage/proposal/lvm_helper"
require "y2storage/proposal/partition_creator"

module Y2Storage
  module Proposal
    # Class to create and reuse devices during the AutoYaST proposal, based
    # on the information contained in the profile.
    #
    # This class receives a devicegraph in which the previous devices have
    # already been deleted or resized according to the AutoYaST profile. This
    # is different from the guided setup equivalent step, in which the minimal
    # amount of existing devices are deleted/resized on demand while trying to
    # allocate the planned devices.
    class AutoinstDevicesCreator
      include Yast::Logger

      # Constructor
      #
      # @param original_graph [Devicegraph] Devicegraph to be used as starting point
      def initialize(original_graph)
        @original_graph = original_graph
      end

      # Devicegraph including all the specified planned devices
      #
      # @param planned_devices [Array<Planned::Partition>] Devices to create/reuse
      # @param disk_names [Array<String>] Disks to consider
      # @return [Devicegraph] New devicegraph in which all the planned devices have been allocated
      def populated_devicegraph(planned_devices, disk_names)
        planned_partitions = planned_devices.select { |dev| dev.is_a?(Planned::Partition) }
        reused, created = planned_partitions.partition(&:reuse?)

        log.info "Partitions to reuse (#{reused.map(&:reuse)}): #{reused}"
        log.info "Partitions to create: #{created}"

        dist = best_distribution(created, disk_names)
        raise Error, "Could not find a valid partitioning distribution" if dist.nil?
        part_creator = Proposal::PartitionCreator.new(original_graph)
        result = part_creator.create_partitions(dist)

        reused.each { |r| r.reuse!(result.devicegraph) }

        vgs = planned_devices.select { |dev| dev.is_a?(Planned::LvmVg) }
        add_volume_groups(vgs, result.devicegraph, result.devices_map)
      end

    protected

      # @return [Devicegraph] Original devicegraph
      attr_reader :original_graph

      # Finds the best distribution for the given planned partitions
      #
      # @param planned_partitions [Array<Planned::Partition>] Partitions to add
      # @param disk_names         [Array<String>]             Names of disks to consider
      #
      # @see Proposal::PartitionsDistributionCalculator#best_distribution
      def best_distribution(planned_partitions, disk_names)
        disks = original_graph.disk_devices.select { |d| disk_names.include?(d.name) }
        spaces = disks.map(&:free_spaces).flatten
        # TODO: the calculator should not enforce the usage of LvmHelper
        calculator = Proposal::PartitionsDistributionCalculator.new(Proposal::LvmHelper.new([]))

        calculator.best_distribution(planned_partitions, spaces)
      end

    private

      # Adds volume groups to the given devicegraph
      #
      # @param vgs         [Array<Planned::LvmVg>]           List of planned volume groups to add
      # @param devicegraph [Devicegraph]                     Starting point
      # @param devices_map [Hash<String,Planned::Partition>] Map of device names and partitions
      # @return [Devicegraph] Devicegraph containing the specified volume groups
      def add_volume_groups(vgs, devicegraph, devices_map)
        vgs.reduce(devicegraph) do |graph, vg|
          lvm_creator = Proposal::LvmCreator.new(graph)
          pvs = find_pvs_for(devices_map, vg.volume_group_name)
          lvm_creator.create_volumes(vg, pvs)
        end
      end

      # Finds physical volumes for a volume group
      #
      # @param devices_map [Hash<String,Planned::Partition>] Map of device names and partitions
      # @param vg_name     [String] Volume group name
      # @return [Array<String>] Physical volumes device names (eg. ["/dev/sda1"])
      #
      # @see Y2Storage::Proposal::PartitionCreator#create_partitions
      def find_pvs_for(devices_map, vg_name)
        devices_map.select { |_k, v| v.lvm_volume_group_name == vg_name }.keys
      end
    end
  end
end
