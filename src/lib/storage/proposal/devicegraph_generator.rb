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
require "storage/proposal/space_maker"
require "storage/proposal/partition_creator"
require "storage/refinements/devicegraph_lists"

module Yast
  module Storage
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
        # @raise Proposal::NoDiskSpaceError if it was not possible to propose a
        #           valid devicegraph
        def devicegraph(volumes, initial_graph, disk_analyzer)
          space_maker = SpaceMaker.new(initial_graph, disk_analyzer, settings)
          graph = provide_space(volumes, space_maker)
          refine_volumes!(volumes, space_maker.deleted_partitions)

          graph = create_partitions(space_maker.distribution, graph)
          reuse_partitions!(volumes, graph)
          graph
        end

      protected

        attr_writer :got_desired_space

        def got_desired_space?
          !!@got_desired_space
        end

        # Provides free disk space in the proposal devicegraph to fit the volumes
        # in. First it tries with the desired space and then with the minimum one
        #
        # @raise Proposal::NoDiskSpaceError if both attempts fail
        #
        # @param volumes [PlannedVolumesList] set of volumes to make space for
        # @param space_maker [SpaceMaker]
        #
        # @return [::Storage::Devicegraph]
        def provide_space(volumes, space_maker)
          self.got_desired_space = false
          begin
            result_graph = space_maker.provide_space(volumes, :desired)
            self.got_desired_space = true
          rescue NoDiskSpaceError
            result_graph = space_maker.provide_space(volumes, :min)
          end
          log.info(
            "Found #{got_desired_space? ? "desired" : "min"} space"
          )
          result_graph
        end

        # Copy of the volumes list with some extra information inferred from the
        # space maker.
        #
        # It enforces reuse of UUIDs and labels from the deleted swap
        # partitions.
        #
        # @param volumes [PlannedVolumesList] original list of volumes
        # @param space_maker [SpaceMaker] an instance in which
        #       SpaceMaker#provide_space has already been called
        # @return [PlannedVolumesList]
        def refine_volumes!(volumes, deleted_partitions)
          deleted_swaps = deleted_partitions.select do |part|
            part.id == ::Storage::ID_SWAP
          end
          new_swap_volumes = volumes.select { |vol| !vol.reuse && vol.mount_point == "swap" }

          new_swap_volumes.each_with_index do |swap_volume, idx|
            deleted_swap = deleted_swaps[idx]
            break unless deleted_swap

            swap_volume.uuid = deleted_swap.filesystem.uuid
            swap_volume.label = deleted_swap.filesystem.label
          end
        end

        # Creates partitions representing a set of volumes
        #
        # Uses the desired or minimum size depending on how much space was freed
        # by #provide_space
        #
        # @param volumes [PlannedVolumesList] set of volumes to create
        # @param initial_graph [::Storage::Devicegraph] initial devicegraph
        #
        # @return [::Storage::Devicegraph]
        def create_partitions(distribution, initial_graph)
          partition_creator = PartitionCreator.new(initial_graph, settings)
          target = got_desired_space? ? :desired : :min
          partition_creator.create_partitions(distribution, target)
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
end
