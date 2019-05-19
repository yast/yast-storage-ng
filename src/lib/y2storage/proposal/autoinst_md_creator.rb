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

require "y2storage/planned"
require "y2storage/proposal/creator_result"
require "y2storage/proposal/autoinst_partition_size"

module Y2Storage
  module Proposal
    # Class to create an MD array according to a Planned::Md following AutoYaST
    # specifications for the sizes
    class AutoinstMdCreator
      include Yast::Logger
      include AutoinstPartitionSize

      # @return [Devicegraph] initial devicegraph
      attr_reader :original_devicegraph

      # Constructor
      #
      # @param original_devicegraph [Devicegraph] Initial devicegraph
      def initialize(original_devicegraph)
        @original_devicegraph = original_devicegraph
      end

      # Creates the MD RAID device
      #
      # @param planned_md   [Planned::Md] MD RAID to create
      # @param device_names [Array<String>] names of block devices that should
      #   be part of the array
      # @return [CreatorResult] Result containing the new MD array
      def create_md(planned_md, device_names)
        new_graph = original_devicegraph.duplicate

        md =
          if planned_md.reuse?
            find_md(new_graph, planned_md.reuse_name)
          else
            create_md_device(new_graph, planned_md, device_names)
          end

        if planned_md.partitions.empty?
          format_md(new_graph, md, planned_md)
        else
          partition_md(new_graph, md, planned_md)
        end
      end

      # Reuses logical volumes for the devicegraph
      #
      # @note This method does not modify the original devicegraph but returns
      #   a new copy containing the changes.
      #
      # @param planned_md [Planned::Md] MD RAID
      # @return [CreatorResult] result containing the reused partitions
      def reuse_partitions(planned_md)
        new_graph = original_devicegraph.duplicate
        planned_md.reuse!(new_graph)
        md = Y2Storage::Md.find_by_name(new_graph, planned_md.reuse_name)
        reused_parts = sized_partitions(planned_md.partitions.select(&:reuse?), device: md)
        shrinking, not_shrinking = reused_parts.partition { |v| v.shrink?(new_graph) }
        (shrinking + not_shrinking).each { |v| v.reuse!(new_graph) }
        CreatorResult.new(new_graph, {})
      end

    private

      # @param devicegraph  [Devicegraph] Devicegraph
      # @param planned_md   [Planned::Md] MD RAID to create
      # @param device_names [Array<String>] names of block devices that should
      #   be part of the array
      # @return [CreatorResult] Result containing the new MD array
      def create_md_device(devicegraph, planned_md, device_names)
        md = Y2Storage::Md.create(devicegraph, planned_md.name)
        md.md_level = planned_md.md_level if planned_md.md_level
        md.chunk_size = planned_md.chunk_size if planned_md.chunk_size
        md.md_parity = planned_md.md_parity if planned_md.md_parity

        devices = device_names.map do |dev_name|
          device = Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name)
          device.encryption || device
        end
        devices.map(&:remove_descendants)
        planned_md.add_devices(md, devices)
        md
      end

      # @param name        [String] MD RAID name
      # @param devicegraph [Devicegraph] Devicegraph to search for the MD RAID
      # @return [Y2Storage::Md,nil] MD RAID device; nil if it is not found
      def find_md(devicegraph, name)
        devicegraph.md_raids.find { |r| r.name == name }
      end

      # Formats the RAID to be used as a filesystem
      #
      # @param planned_md [Planned::Md] Planned MD RAID
      # @return [Proposal::CreatorResult] Result containing the formatted RAID
      def format_md(devicegraph, md, planned_md)
        planned_md.format!(md)
        CreatorResult.new(devicegraph, md.name => planned_md)
      end

      # Creates RAID partitions and set up them according to the plan
      #
      # @param devicegraph [Devicegraph] Devicegraph to work on
      # @param md          [Md] MD RAID
      # @param planned_md  [Planned::Md] Planned MD RAID
      # @return [Proposal::CreatorResult] Result containing the partitioned RAID
      def partition_md(devicegraph, md, planned_md)
        PartitionTableCreator.new.create_or_update(md, planned_md.ptable_type)
        new_partitions = planned_md.partitions.reject(&:reuse?)
        create_partitions(devicegraph, md, sized_partitions(new_partitions, device: md))
      end

      # Creates MD RAID partitions
      #
      # @param devicegraph        [Devicegraph] Devicegraph to operate on
      # @param md                 [Md] MD RAID
      # @param planned_partitions [Array<Planned::Partition>] List of planned partitions to create
      # @return [CreatorResult] Result of creating the partitions
      #
      # @raise NoDiskSpaceError
      def create_partitions(devicegraph, md, planned_partitions)
        dist = best_distribution(md, planned_partitions)
        raise NoDiskSpaceError, "Partitions cannot be allocated into the RAID" if dist.nil?
        part_creator = Proposal::PartitionCreator.new(devicegraph)
        part_creator.create_partitions(dist)
      end

      # Finds the best distribution of partitions within a RAID
      #
      # @param md                 [Md] MD RAID
      # @param planned_partitions [Array<Planned::Partition>] List of planned partitions to create
      # @return [PartitionsDistribution] Distribution of partitions
      def best_distribution(md, planned_partitions)
        spaces = md.free_spaces
        calculator = Proposal::PartitionsDistributionCalculator.new
        calculator.best_distribution(planned_partitions, spaces)
      end
    end
  end
end
