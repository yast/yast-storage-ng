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
require "storage/storage_manager"
require "storage/disk_analyzer"
require "storage/disk_size"
require "storage/free_disk_space"

module Yast
  module Storage
    class Proposal
      # Refinement for ::Storage::Devicegraph with several proposal-oriented
      # methods
      module RefinedDevicegraph
        refine ::Storage::Devicegraph do
          # Free disk space below this size will be disregarded
          TINY_FREE_CHUNK = DiskSize.MiB(30)

          attr_writer :disk_analyzer

          def analyze
            @disk_analyzer = DiskAnalyzer.new
            @disk_analyzer.analyze(self)
          end

          def disk_analyzer
            analyze if @disk_analyzer.nil?
            @disk_analyzer
          end

          alias_method :orig_copy, :copy
          def copy
            new_graph = ::Storage::Devicegraph.new
            orig_copy(new_graph)
            new_graph.disk_analyzer = disk_analyzer
            new_graph
          end

          def candidate_spaces
            spaces = []
            # #each is prefered over #each_with_object by our C++ developers
            candidate_disks_names.each do |disk_name|
              begin
                disk = ::Storage::Disk.find(self, disk_name)
                disk.partition_table.unused_partition_slots.each do |slot|
                  free_slot = FreeDiskSpace.new(disk, slot)
                  spaces << free_slot if free_slot.size >= TINY_FREE_CHUNK
                end
              rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
                log.info("CAUGHT exception #{ex}")
                # FIXME: Handle completely empty disks (no partition table) as empty space
              end
            end
            spaces
          end

          def available_size
            candidate_spaces.map(&:size).reduce(DiskSize.zero, :+)
          end

          # Return all partition names from all candidate disks.
          #
          # @return [Array<String>] partition_names
          def candidate_part_names
            cand_part = []
            # #each is prefered over #each_with_object by our C++ developers
            candidate_disks_names.each do |disk_name|
              begin
                disk = ::Storage::Disk.find(self, disk_name)
                disk.partition_table.partitions.each { |part| cand_part << part.name }
              rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
                log.info("CAUGHT exception #{ex}")
              end
            end
            cand_part
          end

          def candidate_disks_names
            disk_analyzer.candidate_disks
          end

          def linux_part_names
            disk_analyzer.linux_partitions
          end

          def windows_part_names
            disk_analyzer.windows_partitions
          end
        end

        refine ::Storage::Devicegraph.singleton_class do
          def probed(storage: StorageManager.instance)
            probed = storage.probed
            probed.analyze
            probed
          end
        end
      end
    end
  end
end
