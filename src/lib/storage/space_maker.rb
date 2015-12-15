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

require "yast"
require "fileutils"
require_relative "./proposal_volume"
require_relative "./disk_size"
require "pp"

module Yast
  module Storage
    #
    # Class to provide free space for creating new partitions - either by
    # reusing existing unpartitioned space, by deleting existing partitions
    # or by resizing an existing Windows partition.
    #
    class SpaceMaker
      include Yast::Logger

      attr_accessor :volumes, :devicegraph

      # Initialize.
      #
      # @param settings [Storage::Settings] parameters to use
      #
      # @param volumes [Array <ProposalVolume>] volumes to find space for.
      #        The volumes might be changed by this class.
      #
      # @param candidate_disks [Array<string>] device names of disks to install to
      #
      # @param linux_partitions [Array<string>] device names of existing Linux
      #        partitions
      #
      # @param windows_partitions [Array<string>] device names of Windows
      #        partitions that can possibly be resized
      #
      # @param devicegraph [Storage::Devicegraph] device graph to use for any
      #        changes, typically StorageManager.instance.devicegraph("proposal")
      #
      def initialize(settings: ,
                     volumes:            [],
                     candidate_disks:    [],
                     linux_partitions:   [],
                     windows_partitions: [],
                     devicegraph:        nil)
        @settings           = settings
        @volumes            = volumes
        @candidate_disks    = candidate_disks
        @linux_partitions   = linux_partitions
        @windows_partitions = windows_partitions
        @devicegraph        = devicegraph || StorageManager.instance.staging
        @free_space         = []
      end

      # Try to detect empty (unpartitioned) space.
      #
      def find_space
        @free_space = []
        @candidate_disks.each do |disk_name|
          begin
            log.info("Trying to find unpartitioned space on #{disk_name}")
            disk = ::Storage::Disk.find(@devicegraph, disk_name)
            disk.partition_table.unused_partition_slots.each do |slot|
              size = DiskSize.new(slot.region.to_kb(slot.region.length))
              log.info("Found slot: #{slot.region} size #{size} on #{disk_name}")
              @free_space << slot
            end
          rescue RuntimeError => ex # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
            log.info("CAUGHT exception #{ex}")
            # FIXME: Handle completely empty disks (no partition table) as empty space
          end
        end
      end

      # Use force to create space: Try to resize an existing Windows
      # partition or delete partitions until there is enough free space.
      #
      def make_space
        # TO DO
      end

      # Resize an existing MS Windows partition to free up disk space.
      #
      def resize_windows_partition(partition)
        # TO DO
        partition
      end

      # Delete all partitions on a disk.
      #
      # @param disk [::storage::Disk]
      #
      def delete_all_partitions(disk_name)
        log.info("Deleting all partitions on #{disk_name}")
        ptable_type = nil
        begin
          disk = ::Storage::Disk.find(@devicegraph, disk_name)
          ptable_type = disk.partition_table.type # might throw if no partition table
        rescue RuntimeError => ex  # FIXME: rescue ::Storage::Exception when SWIG bindings are fixed
          log.info("CAUGHT exception #{ex}")
        end
        ptable_type ||= disk.default_partition_table_type
        disk.create_partition_table(ptable_type) # this implicitly deletes all partitions
      end

      # Delete one partition.
      #
      def delete_partition(partition)
        # TO DO
      end
    end
  end
end
