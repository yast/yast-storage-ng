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

require "y2storage/planned"
require "y2storage/proposal/creator_result"

module Y2Storage
  module Proposal
    # Class to create a Bcache device according to a Planned::Bcache object
    class BcacheCreator
      include Yast::Logger

      attr_reader :original_devicegraph

      # Constructor
      #
      # @param original_devicegraph [Devicegraph] Initial devicegraph
      def initialize(original_devicegraph)
        @original_devicegraph = original_devicegraph
      end

      # Creates the Bcache device
      #
      # @param planned_bcache  [Planned::Bcache] Bcache device
      # @param backing_devname [String] Backing device name
      # @param caching_devname [String] Caching device name
      # @return [CreatorResult] Result containing the new Bcache device
      def create_bcache(planned_bcache, backing_devname, caching_devname)
        new_graph = original_devicegraph.duplicate
        bcache =
          if planned_bcache.reuse?
            find_bcache(new_graph, planned_bcache.name)
          else
            create_bcache_device(new_graph, planned_bcache, backing_devname, caching_devname)
          end

        if planned_bcache.partitions.empty?
          format_bcache(new_graph, bcache, planned_bcache)
        else
          partition_bcache(new_graph, bcache, planned_bcache)
        end
      end

      # Reuses logical volumes for the devicegraph
      #
      # @note This method does not modify the original devicegraph but returns
      #   a new copy containing the changes.
      #
      # @param planned_bcache [Planned::Bcache] Bcache device
      # @return [CreatorResult] result containing the reused partitions
      def reuse_partitions(planned_bcache)
        new_graph = original_devicegraph.duplicate
        planned_bcache.reuse!(new_graph)
        bcache = Y2Storage::Bcache.find_by_name(new_graph, planned_bcache.reuse_name)
        reused_parts = sized_partitions(planned_bcache.partitions.select(&:reuse?), bcache)
        shrinking, not_shrinking = reused_parts.partition { |v| v.shrink?(new_graph) }
        (shrinking + not_shrinking).each { |v| v.reuse!(new_graph) }
        CreatorResult.new(new_graph, {})
      end

    private

      # @param planned_bcache  [Planned::Bcache] Bcache device
      # @param backing_devname [String] Backing device name
      # @param caching_devname [String] Caching device name
      # @return [Planned::Bcache]
      def create_bcache_device(devicegraph, planned_bcache, backing_devname, caching_devname)
        backing_device = find_blk_device(devicegraph, backing_devname)
        caching_device = find_blk_device(devicegraph, caching_devname)

        backing_device.remove_descendants
        # FIXME: it does not look like the right condition
        if caching_device.descendants.none? { |d| d.is?(:bcache_cset) }
          caching_device.remove_descendants
        end

        # FIXME: solve name collisions
        bcache = backing_device.create_bcache(planned_bcache.name)

        bcache_cset = caching_device.create_bcache_cset
        bcache.add_bcache_cset(bcache_cset)
        bcache
      end

      # @param name        [String] Bcache name
      # @param devicegraph [Devicegraph] Devicegraph to search for the Bcache device
      # @return [Y2Storage::Bcache,nil] Bcache device; nil if it is not found
      def find_bcache(devicegraph, name)
        devicegraph.bcaches.find { |r| r.name == name }
      end

      # Formats the Bcache to be used as a filesystem
      #
      # @param devicegraph    [Devicegraph] Devicegraph to search for the Bcache device
      # @param bcache         [Bcache] Bcache device to format
      # @param planned_bcache [Planned::Bcache] Planned Bcache
      # @return [Proposal::CreatorResult] Result containing the formatted Bcache
      def format_bcache(devicegraph, bcache, planned_bcache)
        planned_bcache.format!(bcache)
        CreatorResult.new(devicegraph, bcache.name => planned_bcache)
      end

      # Creates Bcache partitions and set up them according to the plan
      #
      # @param devicegraph    [Devicegraph] Devicegraph to work on
      # @param bcache         [Bcache] Bcache device to format
      # @param planned_bcache [Planned::Bcache] Planned Bcache
      # @return [Proposal::CreatorResult] Result containing the partitioned Bcache
      def partition_bcache(devicegraph, bcache, planned_bcache)
        PartitionTableCreator.new.create_or_update(bcache, planned_bcache.ptable_type)
        new_partitions = planned_bcache.partitions.reject(&:reuse?)
        create_partitions(devicegraph, bcache, sized_partitions(new_partitions, bcache))
      end

      # Creates Bcache partitions
      #
      # @param devicegraph        [Devicegraph] Devicegraph to operate on
      # @param bcache             [Bcache] Bcache
      # @param planned_partitions [Array<Planned::Partition>] List of planned partitions to create
      # @return [CreatorResult] Result of creating the partitions
      #
      # @raise NoDiskSpaceError
      def create_partitions(devicegraph, bcache, planned_partitions)
        dist = best_distribution(bcache, planned_partitions)
        raise NoDiskSpaceError, "Partitions cannot be allocated into the Bcache" if dist.nil?
        part_creator = Proposal::PartitionCreator.new(devicegraph)
        part_creator.create_partitions(dist)
      end

      # Finds the best distribution of partitions within a Bcache
      #
      # @param bcache                 [Bcache] Bcache
      # @param planned_partitions [Array<Planned::Partition>] List of planned partitions to create
      # @return [PartitionsDistribution] Distribution of partitions
      def best_distribution(bcache, planned_partitions)
        spaces = bcache.free_spaces
        calculator = Proposal::PartitionsDistributionCalculator.new
        calculator.best_distribution(planned_partitions, spaces)
      end

      # Returns a list of planned partitions adjusting the size
      #
      # All partitions which sizes are specified as percentage will get their minimal and maximal
      # sizes adjusted.
      #
      # @param planned_partitions [Array<Planned::Partition>] List of planned partitions
      # @param bcache             [Y2Storage::Bcache] Bcache
      # @return [Array<Planned::Partition>] New list of planned partitions with adjusted sizes
      def sized_partitions(planned_partitions, bcache)
        planned_partitions.map do |part|
          new_part = part.clone
          next new_part unless new_part.percent_size
          new_part.max = new_part.min = new_part.size_in(bcache)
          new_part
        end
      end

      # Finds a block device by name
      #
      # @param devicegraph [Devicegraph] Devicegraph
      # @param dev_name    [String] Device name
      def find_blk_device(devicegraph, dev_name)
        device = Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name)
        device.encryption || device
      end
    end
  end
end
