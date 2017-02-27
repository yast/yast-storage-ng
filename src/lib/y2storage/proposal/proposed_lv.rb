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
require "y2storage/proposal/proposed_device"

module Y2Storage
  # Class to represent a planned volume (partition or logical volume) and
  # its constraints
  #
  class ProposedLv < ProposedDevice
    # @return [String] name to use if the volume is placed in LVM
    attr_accessor :logical_volume_name

    # Constructor.
    #
    # @param mount_point [string] @see #mount_point
    # @param filesystem_type [::Storage::FsType] @see #filesystem_type
    def initialize(volume: nil, target: nil)
      super
      @logical_volume_name = nil
      return unless @mount_point
      @logical_volume_name = @mount_point == "/" ? "root" : @mount_point.sub(%r{^/}, "")
    end
  end
end
