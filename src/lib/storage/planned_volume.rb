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
require "storage/disk_size"

module Yast
  module Storage
    # Class to represent a planned volume (partition or logical volume) and
    # its constraints
    #
    class PlannedVolume
      attr_accessor :mount_point, :filesystem_type
      attr_accessor :size, :min_size, :max_size, :desired_size, :weight
      attr_accessor :can_live_on_logical_volume, :logical_volume_name

      alias_method :desired, :desired_size
      alias_method :min, :min_size
      alias_method :max, :max_size

      # Constructor.
      #
      # @param mount_point [string] mount point for this volume. This might be
      #        a real mount point ("/", "/boot", "/home") or a pseudo mount
      #        point like "swap".
      #
      # @param filesystem_type [::Storage::FsType] the type of filesystem this
      #        volume should get. Typically one of ::Storage::FsType_BTRFS,
      #        ::Storage::FsType_EXT4, ::Storage::FsType_XFS,
      #        ::Storage::FsType_SWAP
      #
      def initialize(mount_point, filesystem_type = nil)
        @mount_point = mount_point
        @filesystem_type = filesystem_type
        @size         = DiskSize.zero
        @min_size     = DiskSize.zero
        @max_size     = DiskSize.unlimited
        @desired_size = DiskSize.unlimited
        @weight       = 0 # For distributing extra space if desired is unlimited
        @can_live_on_logical_volume = false
        @logical_volume_name = nil

        return unless @mount_point.start_with?("/")
        return if @mount_point.start_with?("/boot")

        @can_live_on_logical_volume = true
        if @mount_point == "/"
          @logical_volume_name = "root"
        else
          @logical_volume_name = @mount_point.sub(%r{^/}, "")
        end
      end
    end
  end
end
