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

require "storage/storage_manager"
require "storage/disk_analyzer"
require "storage/proposal/space_maker"
require "storage/proposal/partition_creator"

module Yast
  module Storage
    class Proposal
      # Class to create devicegraphs that can accommodate a given collection of
      # volumes
      class DevicegraphGenerator
        include Yast::Logger

        attr_accessor :settings

        def initialize(settings)
          @settings = settings
        end

        # Devicegraph including all the specified volumes
        #
        # @param volumes [PlannedVolumesList] volumes to accommodate
        # @param initial_graph [::Storage::Devicegraph] initial devicegraph
        #           (typically the representation of the current system)
        # @return [::Storage::Devicegraph]
        # @raise Proposal::NoDiskSpaceError if it was not possible to propose a
        #           valid devicegraph
        def devicegraph(volumes, initial_graph: StorageManager.instance.probed)
          disk_analyzer.analyze(initial_graph)
          graph = provide_space(volumes, initial_graph)
          graph = create_partitions(volumes, graph)
          graph
        end

      protected

        attr_writer :got_desired_space

        def got_desired_space?
          !!@got_desired_space
        end

        # Disk analyzer used to analyze the initial devigraph
        #
        # @return [DiskAnalyzer]
        def disk_analyzer
          @disk_analyzer ||= DiskAnalyzer.new
        end

        # Provides free disk space in the proposal devicegraph to fit the volumes
        # in. First it tries with the desired space and then with the minimum one
        #
        # @raise Proposal::NoDiskSpaceError if both attempts fail
        #
        # @param volumes [PlannedVolumesList] set of volumes to make space for
        # @param initial_graph [::Storage::Devicegraph] proposal-refined initial
        #           devicegraph (@see RefinedDevicegraph)
        # @return [::Storage::Devicegraph]
        def provide_space(volumes, initial_graph)
          space_maker = SpaceMaker.new(initial_graph, disk_analyzer)
          self.got_desired_space = false
          begin
            result_graph = space_maker.provide_space(volumes.desired_size)
            self.got_desired_space = true
          rescue NoDiskSpaceError
            result_graph = space_maker.provide_space(volumes.min_size)
          end
          log.info(
            "Found #{got_desired_space? ? "desired" : "min"} space"
          )
          result_graph
        end

        # Creates partitions representing a set of volumes
        #
        # Uses the desired or minimum size depending on how much space was freed
        # by #provide_space
        #
        # @param volumes [PlannedVolumesList] set of volumes to create
        # @param initial_graph [::Storage::Devicegraph] proposal-refined initial
        #           devicegraph (@see RefinedDevicegraph)
        # @return [::Storage::Devicegraph]
        def create_partitions(volumes, initial_graph)
          partition_creator = PartitionCreator.new(initial_graph, disk_analyzer, settings)
          target = got_desired_space? ? :desired : :min
          partition_creator.create_partitions(volumes, target)
        end
      end
    end
  end
end
