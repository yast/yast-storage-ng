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
require_relative "./proposal_volume"
require_relative "./disk_size"
require "pp"

module Yast
  module Storage
    #
    # Class to provide free space for creating new partitions - either by
    # reusing existing unpartitioned space, by deleting existing partitions
    # or by resizing an existing Windows partiton.
    #
    class SpaceMaker
      include Yast::Logger

      attr_reader :volumes

      # Initialize.
      # @param volumes [list of ProposalVolume] volumes to find space for.
      # The volumes might be changed by this class.
      #
      # @param settings [Storage::Settings] parameters to use
      #
      def initialize(volumes, settings)
        @volumes  = volumes
        @settings = settings
        storage = StorageManager.instance
      end

      # Try to detect empty (unpartitioned) space.
      def find_space
      end

      # Use force to create space: Try to resize an existing Windows
      # partition or delete partitions until there is enough free space.
      def make_space
      end

      # Check if there are any Linux partitions on any of the disks.
      # This may be a normal Linux partition (type 0x83), a Linux swap
      # partition (type 0x82), an LVM partition, or a RAID partition.
      def linux_partitions?
      end

      # Check if there is a MS Windows partition that could possibly be
      # resized.
      #
      # @return [bool] 'true# if there is a Windows partition, 'false' if not.
      def windows_partition?
        # TO DO
        false
      end

      # Resize an existing MS Windows partition to free up disk space.
      def resize_windows_partition
        # TO DO
      end
    end
  end
end
