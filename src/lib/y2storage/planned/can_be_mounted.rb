#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2015-2017] SUSE LLC
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
require "y2storage/mountable"

module Y2Storage
  module Planned
    # Mixin for planned devices that can have a mount point.
    # @see Planned::Device
    module CanBeMounted
      # @return [String] mount point for this planned device. This might be a
      #   real mount point ("/", "/boot", "/home") or a pseudo mount point like
      #   "swap".
      attr_accessor :mount_point

      # Initializations of the mixin, to be called from the class constructor.
      def initialize_can_be_mounted
      end

      # Checks whether this device is shadowed by any of the given mount points
      # @see Mountable#shadowing?
      #
      # @param other_mount_points [Array<String>]
      #
      # @return [Boolean]
      def shadowed?(other_mount_points)
        return false if mount_point.nil? || other_mount_points.nil?
        other_mount_points.compact.any? { |m| Mountable.shadowing?(m, mount_point) }
      end
    end
  end
end
