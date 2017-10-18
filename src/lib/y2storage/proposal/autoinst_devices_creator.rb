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
require "y2storage/proposal/md_creator"
require "y2storage/exceptions"

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
      # @param planned_devices [Array<Planned::Device>] Devices to create/reuse
      # @param disk_names [Array<String>] Disks to consider
      # @return [Devicegraph] New devicegraph in which all the planned devices have been allocated
      def populated_devicegraph(planned_devices, disk_names)
        # Process planned partitions
        planned_partitions = planned_devices.select { |d| d.is_a?(Planned::Partition) }
        parts_to_reuse, parts_to_create = planned_partitions.partition(&:reuse?)
        creator_result = create_partitions(parts_to_create, disk_names)
        reuse_partitions(parts_to_reuse, creator_result.devicegraph)

        # Process planned MD arrays
        planned_mds = planned_devices.select { |d| d.is_a?(Planned::Md) }
        mds_to_reuse, mds_to_create = planned_mds.partition(&:reuse?)
        creator_result.merge!(create_mds(mds_to_create, creator_result))
        mds_to_reuse.each { |i| i.reuse!(creator_result.devicegraph) }

        # Process planned volume groups
        planned_vgs = planned_devices.select { |d| d.is_a?(Planned::LvmVg) }
        creator_result.merge!(set_up_lvm(planned_vgs, creator_result))
        vgs_to_reuse = planned_vgs.select(&:reuse?)
        reuse_vgs(vgs_to_reuse, creator_result.devicegraph)

        creator_result.devicegraph
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

      # Creates planned partitions in the given devicegraph
      #
      # @param new_partitions [Array<Planned::Partition>] Devices to create
      # @param disk_names     [Array<String>]             Disks to consider
      # @return [PartitionCreatorResult]
      def create_partitions(new_partitions, disk_names)
        log.info "Partitions to create: #{new_partitions}"

        dist = best_distribution(new_partitions, disk_names)
        raise NoDiskSpaceError, "Could not find a valid partitioning distribution" if dist.nil?
        part_creator = Proposal::PartitionCreator.new(original_graph)
        part_creator.create_partitions(dist)
      end

      # Creates volume groups in the given devicegraph
      #
      # @param vgs             [Array<Planned::LvmVg>]   List of planned volume groups to add
      # @param previous_result [Proposal::CreatorResult] Starting point
      # @return                [Proposal::CreatorResult] Result containing the specified volume groups
      def set_up_lvm(vgs, previous_result)
        log.info "BEGIN: set_up_lvm: vgs=#{vgs.inspect} previous_result=#{previous_result.inspect}"
        vgs.reduce(previous_result) do |result, vg|
          lvm_creator = Proposal::LvmCreator.new(result.devicegraph)
          pvs = previous_result.created_names { |d| d.pv_for?(vg.volume_group_name) }
          result.merge(lvm_creator.create_volumes(vg, pvs))
        end
      end

      # Reuses partitions for the given devicegraph
      #
      # @param reused_partitions [Array<Planned::Partition>] Partitions to reuse
      # @param devicegraph       [Devicegraph]               Devicegraph to reuse partitions
      def reuse_partitions(reused_partitions, devicegraph)
        reused_partitions.each { |r| r.reuse!(devicegraph) }
      end

      # Reuses volume groups for the given devicegraph
      #
      # @param reused_vgs  [Array<Planned::LvmVg>] Volume groups to reuse
      # @param devicegraph [Devicegraph]           Devicegraph to reuse partitions
      def reuse_vgs(reused_vgs, devicegraph)
        reused_vgs.each do |vg|
          vg.reuse!(devicegraph)
          vg.lvs.select(&:reuse?).each { |v| v.reuse!(devicegraph) }
        end
      end

      # Creates MD RAID devices in the given devicegraph
      #
      # @param mds             [Array<Planned::Md>]      List of planned MD arrays to create
      # @param previous_result [Proposal::CreatorResult] Starting point
      # @return                [Proposal::CreatorResult] Result containing the specified MD RAIDs
      def create_mds(mds, previous_result)
        mds.reduce(previous_result) do |result, md|
          md_creator = Proposal::MdCreator.new(result.devicegraph)
          devices = previous_result.created_names { |d| d.raid_name == md.name }
          result.merge(md_creator.create_md(md, devices))
        end
      end
    end
  end
end
