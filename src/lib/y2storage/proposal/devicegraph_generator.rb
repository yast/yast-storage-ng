#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "storage"
require "y2storage/proposal/space_maker"
require "y2storage/proposal/partition_creator"
require "y2storage/proposal/lvm_helper"
require "y2storage/refinements/devicegraph_lists"

module Y2Storage
  class Proposal
    # Class to create devicegraphs that can accommodate a given collection of
    # volumes
    class DevicegraphGenerator
      include Yast::Logger

      using Refinements::DevicegraphLists

      attr_accessor :settings

      def initialize(settings)
        @settings = settings
      end

      # Devicegraph including all the specified volumes
      #
      # @param volumes [PlannedVolumesList] volumes to accommodate
      # @param initial_graph [::Storage::Devicegraph] initial devicegraph
      #           (typically the representation of the current system)
      # @param disk_analyzer [DiskAnalyzer] analysis of the initial_graph
      #
      # @return [::Storage::Devicegraph]
      # @raise Proposal::Error if it was not possible to propose a devicegraph
      def devicegraph(volumes, initial_graph, disk_analyzer)
        begin
          provide_space(volumes, initial_graph, disk_analyzer, target: :desired)
        rescue NoDiskSpaceError
          provide_space(volumes, initial_graph, disk_analyzer, target: :min)
        end
      end

    protected

      # Provides free disk space in the proposal devicegraph to fit the
      # volumes in.
      #
      # @raise Proposal::Error if the goal is not reached
      #
      # @param no_lvm_volumes [PlannedVolumesList] set of non-LVM volumes to
      #     make space for. The LVM volumes are already handled by
      #     space_make#lvm_helper
      # @param space_maker [SpaceMaker]
      #
      # @return [::Storage::Devicegraph]
      def provide_space(volumes, initial_graph, disk_analyzer, target: nil)
        proposed_partitions = proposed_partitions(volumes, target: target)
        proposed_lvs = proposed_lvs(volumes, target: target)
        reused_partitions = reused_partitions(volumes)

        lvm_helper = LvmHelper.new(proposed_lvs, encryption_password: settings.encryption_password)
        space_maker = SpaceMaker.new(initial_graph, disk_analyzer, lvm_helper, settings)

        if settings.use_lvm
          result = provide_space_lvm(proposed_partitions, reused_partitions, space_maker)
        else
          result = provide_space_no_lvm(proposed_partitions, reused_partitions, space_maker)
        end

        graph = result[:devicegraph]
        space_distribution = result[:space_distribution]
        deleted_partitions = result[:deleted_partitions]

        refine_partitions!(space_distribution, deleted_partitions)
        final_graph = create_partitions(space_distribution, graph)
        reuse_partitions!(volumes, final_graph)

        if settings.use_lvm
          new_pvs = new_physical_volumes(graph, final_graph)
          final_graph = lvm_helper.create_volumes(final_graph, new_pvs)
        end

        final_graph
      end

      def proposed_partitions(volumes, target: nil)
        volumes = volumes.reject(&:reuse)
        partitions = proposed_plain_partitions(volumes, target: target)
        unless settings.use_lvm
          partitions += proposed_not_plain_partitions(volumes, target: target)
        end
        partitions
      end

      def proposed_plain_partitions(volumes, target: nil)
        volumes = volumes.select(&:plain_partition?) 
        volumes.map { |volume| ProposedPartition.new(volume: volume, target: target) }
      end

      def proposed_not_plain_partitions(volumes, target: nil)
        volumes = volumes.reject(&:plain_partition?)
        partitions = volumes.map { |volume| ProposedPartition.new(volume: volume, target: target) }
        partitions.each { |partition| partition.encryption_password = settings.encryption_password }
        partitions
      end

      def proposed_lvs(volumes, target: nil)
        return [] unless settings.use_lvm
        volumes = volumes.reject(&:plain_partition?)
        lvs = volumes.map { |volume| ProposedLv.new(volume: volume, target: target)}
        lvs.each { |lv| lv.encryption_password = settings.encryption_password }
        lvs
      end

      def reused_partitions(volumes)
        volumes.map(&:reuse).compact
      end

      # Variant of #provide_space when LVM is not involved
      # @see #provide_space
      def provide_space_no_lvm(proposed_partitions, reused_partitions, space_maker)
        result = space_maker.provide_space(proposed_partitions, partitions_to_keep: reused_partitions)
        log.info "Found space"
        result
      end

      # Variant of #provide_space when LVM is involved. It first tries to reuse
      # the existing volume groups (one at a time). If that fails, it tries to
      # create a new volume group from scratch.
      #
      # @see #provide_space
      def provide_space_lvm(proposed_partitions, reused_partitions, space_maker)
        lvm_helper = space_maker.lvm_helper
        lvm_helper.reused_volume_group = nil

        lvm_helper.reusable_volume_groups(space_maker.original_graph).each do |vg|
          begin
            lvm_helper.reused_volume_group = vg
            keep = reused_partitions + lvm_helper.partitions_in_vg
            result = space_maker.provide_space(proposed_partitions, partitions_to_keep: keep)
            log.info "Found space including LVM, reusing #{vg}"
            return result
          rescue NoDiskSpaceError
            next
          end
        end

        lvm_helper.reused_volume_group = nil
        result = space_maker.provide_space(proposed_partitions, partitions_to_keep: reused_partitions)
        log.info "Found space including LVM"

        result
      end

      # List of partitions with LVM id (i.e. potential physical volumes) that
      # are present in the new devicegraph but were not there in the old one.
      #
      # @param old_devicegraph [Storage::Devicegraph]
      # @param new_devicegraph [Storage::Devicegraph]
      # @return [Array<String>] device names of the partitions
      def new_physical_volumes(old_devicegraph, new_devicegraph)
        all_pvs = new_devicegraph.partitions.with(id: Storage::ID_LVM)
        old_pv_sids = old_devicegraph.partitions.with(id: Storage::ID_LVM).map(&:sid)
        all_pvs.reject { |pv| old_pv_sids.include?(pv.sid) }.map(&:name)
      end

      # Adds some extra information to the planned volumes inferred from
      # the list of partitions deleted by the space maker.
      #
      # It enforces reuse of UUIDs and labels from the deleted swap
      # partitions.
      #
      # It modifies the passed volumes.
      #
      # @param volumes [PlannedVolumesList] list of volumes to modify
      # @param deleted_partitions [Array<::Storage::Partition>] partitions
      #     deleted from the initial devicegraph
      def refine_partitions!(space_distribution, deleted_partitions)
        partitions = space_distribution.spaces.map { |s| s.partitions }.flatten

        deleted_swaps = deleted_partitions.select do |part|
          part.id == ::Storage::ID_SWAP
        end
        new_swap_partitions = partitions.select { |part| part.mount_point == "swap" }

        new_swap_partitions.each_with_index do |swap_partition, idx|
          deleted_swap = deleted_swaps[idx]
          break unless deleted_swap

          swap_partition.uuid = deleted_swap.filesystem.uuid
          swap_partition.label = deleted_swap.filesystem.label
        end
      end

      # Creates partitions representing a set of volumes
      #
      # @param volumes [PlannedVolumesList] set of volumes to create
      # @param initial_graph [::Storage::Devicegraph] initial devicegraph
      #
      # @return [::Storage::Devicegraph]
      def create_partitions(distribution, initial_graph)
        partition_creator = PartitionCreator.new(initial_graph)
        partition_creator.create_partitions(distribution)
      end

      # Adjusts pre-existing (not created by us) partitions assigning its
      # mount point and boot flag
      #
      # It works directly on the passed devicegraph
      #
      # @param volumes [PlannedVolumesList] set of volumes to create
      # @param graph [::Storage::Devicegraph] devicegraph to modify
      def reuse_partitions!(volumes, graph)
        volumes.select { |v| v.reuse }.each do |vol|
          partition = graph.partitions.with(name: vol.reuse).first
          filesystem = partition.filesystem
          filesystem.add_mountpoint(vol.mount_point) if vol.mount_point && !vol.mount_point.empty?
          partition.boot = true if vol.bootable
        end
      end
    end
  end
end
