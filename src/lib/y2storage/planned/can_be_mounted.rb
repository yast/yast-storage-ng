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

module Y2Storage
  module Planned
    # Mixing for planned devices that can have a mount point.
    # @see Planned::Device
    module CanBeMounted
      # @return [String] mount point for this planned device. This might be a
      #   real mount point ("/", "/boot", "/home") or a pseudo mount point like
      #   "swap".
      attr_accessor :mount_point

      # Initializations of the mixin, to be called from the class constructor.
      def initialize_can_be_mounted
      end

      # Check if 'mount_point' shadows any of the mount points in
      # 'other_mount_points'.
      #
      # @param mount_point [String] mount point to check
      # @param other_mount_points [Array<String>]
      #
      # @return [Boolean]
      #
      # TODO: this is probably misplaced here, but is not called in the unit
      # test suite, so I will fix it in an upcoming commit
      def shadows?(mount_point, other_mount_points)
        return false if mount_point.nil? || other_mount_points.nil?
        # Just checking with start_with? is not sufficient:
        # "/bootinger/schlonz".start_with?("/boot") -> true
        # So append "/" to make sure only complete subpaths are compared:
        # "/bootinger/schlonz/".start_with?("/boot/") -> false
        # "/boot/schlonz/".start_with?("/boot/") -> true
        mount_point += "/"
        other_mount_points.any? do |other|
          next false if other.nil?
          mount_point.start_with?(other + "/")
        end
      end
    end
  end
end
