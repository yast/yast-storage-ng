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
require_relative "./disk_analyzer"
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

      attr_reader :volumes

      # Initialize.
      #
      # @param volumes [Array <ProposalVolume>] volumes to find space for.
      # The volumes might be changed by this class.
      #
      # @param settings [Storage::Settings] parameters to use
      #
      # @param disk_analyzer [DiskAnalyzer]
      #
      def initialize(volumes, settings, disk_analyzer)
        @volumes  = volumes
        @settings = settings
        @disk_analyzer = disk_analyzer
        @free_space = []
      end

      # Try to detect empty (unpartitioned) space.
      def find_space
        @free_space = []
        @disk_analyzer.candidate_disks.each do |disk|
          begin
            disk.partition_table.unused_partition_slots.each do |slot|
              size = DiskSize.new(slot.region.to_kb(slot.region.length))
              log.info("Found slot: #{slot.region} size #{size} on #{disk}")
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
      def make_space
        # TO DO
      end

      # Resize an existing MS Windows partition to free up disk space.
      def resize_windows_partition(partition)
        # TO DO
        partition
      end
    end
  end
end
