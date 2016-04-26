#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
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

require "fileutils"
require "storage"
require "storage/planned_volume"
require "storage/disk_size"
require "storage/free_disk_space"
require "storage/refinements/devicegraph"
require "storage/refinements/devicegraph_lists"

module Yast
  module Storage
    class Proposal
      # Class to provide free space for creating new partitions - either by
      # reusing existing unpartitioned space, by deleting existing partitions
      # or by resizing an existing Windows partition.
      class SpaceMaker
        using Refinements::Devicegraph
        using Refinements::DevicegraphLists
        include Yast::Logger

        attr_accessor :settings

        # Initialize.
        #
        # @param original_graph [::Storage::Devicegraph] initial devicegraph
        # @param disk_analyzer [DiskAnalyzer] information about original_graph
        # @param settings [Proposal::Settings] proposal settings
        def initialize(original_graph, disk_analyzer, settings)
          @original_graph = original_graph
          @disk_analyzer = disk_analyzer
          @settings = settings
        end

        # Returns a copy of the original devicegraph in which all needed
        # operations to free the required size have been performed
        #
        # @raise Proposal::NoDiskSpaceError if there is no enough room
        #
        # @param required_size [DiskSize] required amount of available space
        # @return [::Storage::Devicegraph]
        def provide_space(required_size)
          new_graph = original_graph.copy

          resize_windows!(new_graph, required_size) unless success?(new_graph, required_size)
          delete_partitions!(new_graph, required_size) unless success?(new_graph, required_size)
          raise NoDiskSpaceError unless success?(new_graph, required_size)

          new_graph
        end

      protected

        attr_reader :original_graph, :disk_analyzer

        # Checks whether the goal has already being reached
        #
        # @return [Boolean]
        def success?(graph, required_size)
          missing_required_size(graph, required_size) <= DiskSize.zero
        end

        # @return [DiskSize]
        def available_size(graph)
          free_spaces(graph).disk_size
        end

        # Additional space that needs to be freed in order to reach the goal
        #
        # @return [DiskSize]
        def missing_required_size(graph, required_size)
          required_size - available_size(graph)
        end

        # List of free spaces in the given devicegraph
        #
        # @return [FreeDiskSpacesList]
        def free_spaces(graph)
          disks_for(graph).free_disk_spaces.with do |space|
            space.size >= settings.useful_free_space_min_size
          end
        end

        # List of candidate disks in the given devicegraph
        #
        # @param devicegraph [::Storage::Devicegraph]
        # @return [DisksList]
        def disks_for(devicegraph)
          devicegraph.disks.with(name: candidate_disk_names)
        end

        # @return [Array<String>]
        def candidate_disk_names
          settings.candidate_devices
        end

        # Try to resize the existing windows partitions - unless there already is
        # a Linux partition which means that
        #
        # @param devicegraph [DeviceGraph] devicegraph to update
        # @param required_size [DiskSize]
        def resize_windows!(devicegraph, required_size)
          windows_part_names = disk_analyzer.windows_partitions
          return if windows_part_names.empty?
          return unless disk_analyzer.linux_partitions.empty?

          log.info("Resizing Windows partitions to free #{required_size}")
          sorted_resizables(devicegraph, windows_part_names).each do |res|
            shrink_size = [
              res[:recoverable_size],
              missing_required_size(devicegraph, required_size)
            ].min
            shrink_partition(res[:partition], shrink_size)
            return if success?(devicegraph, required_size)
          end
          log.info "Didn't manage to free enough space by resizing Windows"
        end

        # List of partitions that can be resized, including the size of the
        # space that can be reclaimed for each partition.
        #
        # The list is sorted so the partitions with more recoverable space are
        # listed first.
        #
        # @param graph [::Storage::Devicegraph]
        # @param part_names [Array<String>] list of partition names to consider
        # @return [Array<Hash>] each element contains
        #     :partition (::Storage::Partition) and :recoverable_size (DiskSize)
        def sorted_resizables(graph, part_names)
          partitions = graph.partitions.with(name: part_names)
          resizables = partitions.map do |part|
            { partition: part, recoverable_size: recoverable_size(part) }
          end
          resizables.delete_if { |res| res[:recoverable_size].zero? }
          resizables.sort_by { |res| res[:recoverable_size] }.reverse
        end

        # Size of the space that can be reclaimed in a partition
        #
        # @param partition [::Storage::Partition]
        # @return [DiskSize]
        def recoverable_size(partition)
          info = partition.filesystem.detect_resize_info
          return DiskSize.zero unless info.resize_ok
          DiskSize.KiB(partition.size_k - info.min_size_k)
        end

        # Reduces the size of a partition
        #
        # @param partition [::Storage::Partition]
        # @param shrink_size [DiskSize] size of the space to substract
        def shrink_partition(partition, shrink_size)
          log.info "Shrinking #{partition.name} by #{shrink_size}"
          partition.size_k = partition.size_k - shrink_size.size_k
        end

        # Use force to create space (up to 'required_size'): Delete partitions
        # until there is enough free space.
        #
        # @param devicegraph [DeviceGraph] devicegraph to update
        # @param required_size [DiskSize]
        def delete_partitions!(devicegraph, required_size)
          log.info("Trying to make space for #{required_size}")

          prioritized_candidate_partitions.each do |part_name|
            return if success?(devicegraph, required_size)
            part = ::Storage::Partition.find(devicegraph, part_name)
            next unless part
            log.info("Deleting partition #{part_name} in device graph")
            part.partition_table.delete_partition(part_name)
          end
        end

        # Return a prioritized array of candidate partitions (from all candidate
        # disks) in this order:
        #
        # - Linux partitions
        # - Non-Linux and non-Windows partitions
        # - Windows partitions
        #
        # @return [Array<String>] partition_names
        def prioritized_candidate_partitions
          candidate_parts = disks_for(original_graph).partitions

          win_part, non_win_part = candidate_parts.map(&:name).partition do |part_name|
            disk_analyzer.windows_partitions.include?(part_name)
          end
          linux_part, non_linux_part = non_win_part.partition do |part_name|
            disk_analyzer.linux_partitions.include?(part_name)
          end

          linux_part + non_linux_part + win_part
        end
      end
    end
  end
end
