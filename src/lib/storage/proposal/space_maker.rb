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
require "storage/proposal/refined_devicegraph"

module Yast
  module Storage
    class Proposal
      # Class to provide free space for creating new partitions - either by
      # reusing existing unpartitioned space, by deleting existing partitions
      # or by resizing an existing Windows partition.
      class SpaceMaker
        using RefinedDevicegraph
        include Yast::Logger

        # Initialize.
        #
        # @param original_graph [::Storage::Devicegraph] initial devicegraph
        def initialize(original_graph)
          @original_graph = original_graph
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

        attr_reader :original_graph

        def success?(graph, required_size)
          graph.available_size >= required_size
        end

        # Try to resize an existing windows partition - unless there already is
        # a Linux partition which means that
        #
        # @param devicegraph [DeviceGraph] devicegraph to update
        # @param required_size [DiskSize]
        def resize_windows!(devicegraph, required_size)
          return if devicegraph.windows_part_names.empty?
          return unless devicegraph.linux_part_names.empty?

          log.info("Resizing Windows partition to free #{required_size}")
          #
          # TO DO: Resize windows partition (not available in libstorage-bgl yet)
          # TO DO: Resize windows partition (not available in libstorage-bgl yet)
          # TO DO: Resize windows partition (not available in libstorage-bgl yet)
          #
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
          windows_partitions = original_graph.windows_part_names
          linux_partitions = original_graph.linux_part_names

          win_part, non_win_part = original_graph.candidate_part_names.partition do |part|
            windows_partitions.include?(part)
          end
          linux_part, non_linux_part = non_win_part.partition do |part|
            linux_partitions.include?(part)
          end

          linux_part + non_linux_part + win_part
        end
      end
    end
  end
end
