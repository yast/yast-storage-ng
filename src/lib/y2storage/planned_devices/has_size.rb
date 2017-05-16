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
require "y2storage/disk_size"

module Y2Storage
  module PlannedDevices
    # Mixing enabling some classes of planned devices to specify the size of the
    # final device in a flexible way.
    # @see PlannedDevices::Base
    module HasSize
      # @return [DiskSize] definitive size of the device
      attr_accessor :size

      # @!attribute min_size
      #   minimum acceptable size
      #
      #   @return [DiskSize] zero for reused volumes
      attr_writer :min_size

      # @return [DiskSize] maximum acceptable size
      attr_accessor :max_size

      # @return [Float] factor used to distribute the extra space
      #   between devices
      attr_accessor :weight

      # Initializations of the mixin, to be called from the class constructor.
      def initialize_has_size
        self.size     = DiskSize.zero
        self.min_size = DiskSize.zero
        self.max_size = DiskSize.unlimited
        self.weight   = 0
      end

      def min_size
        # No need to provide space for reused volumes
        (respond_to?(:reuse) && reuse) ? DiskSize.zero : @min_size
      end

      alias_method :min, :min_size
      alias_method :max, :max_size
      alias_method :min=, :min_size=
      alias_method :max=, :max_size=
    end
  end
end
