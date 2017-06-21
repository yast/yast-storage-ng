#!/usr/bin/env ruby
#
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
require "y2storage/planned/device"
require "y2storage/planned/mixins"

module Y2Storage
  module Planned
    # Specification for Y2Storage::LvmVg object to be created during the
    # storage or AutoYaST proposals
    #
    # @see Device
    class LvmVg < Device
      include Planned::HasSize

      DEFAULT_VG_NAME = "system".freeze

      DEFAULT_EXTENT_SIZE = DiskSize.MiB(4)
      private_constant :DEFAULT_EXTENT_SIZE

      # @return [String] name to use for Y2Storage::LvmVg#vg_name
      attr_accessor :volume_group_name

      # @return [Array<Planned::LvmLv>] List of logical volumes
      attr_accessor :lvs

      # @return [Array<Planned::Device>] List of physical volumes
      attr_accessor :pvs

      # @return [DiskSize] Size of one extent
      attr_accessor :extent_size

      # @return [DiskSize] Total size of the volume group
      attr_writer :total_size

      # Builds a new instance based on a real VG
      #
      # It copies information from the real VG to make sure it is available
      # even if the real object disappears.
      #
      # @return [LvmVg] Volume group to base on
      def self.from_real_vg(real_vg)
        new(volume_group_name: real_vg.vg_name).tap do |vg|
          vg.extent_size = real_vg.extent_size
          vg.total_size = real_vg.total_size
          vg.pvs = real_vg.lvm_pvs.map { |v| v.blk_device.name }
          vg.lvs = real_vg.lvm_lvs.map { |v| LvmLv.from_real_lv(v) }
          vg.reuse = real_vg.vg_name
        end
      end

      # Constructor
      #
      # @param volume_group_name [String] Name of the volume group
      # @param lvs               [Array<Planned::LvmLv>] List of planned logical volumes
      # @param pvs               [Array<String>] Name of partitions to be used as physical volumes
      def initialize(volume_group_name: nil, lvs: [], pvs: [])
        initialize_has_size
        @volume_group_name = volume_group_name || DEFAULT_VG_NAME
        @lvs = lvs
        @pvs = pvs
      end

      # Returns the size of each extent
      #
      # @return [DiskSize]
      def extent_size
        @extent_size ||= DEFAULT_EXTENT_SIZE
      end

      # Determines the space needed to acommodate this volume group
      #
      # @return [DiskSize]
      def target_size
        DiskSize.sum(lvs.map(&:min_size), rounding: extent_size)
      end

      # Determines the space currently used by the volume group
      #
      # It will be DiskSize.zero if it does not exist yet.
      #
      # @return [DiskSize]
      def total_size
        @total_size ||= DiskSize.zero
      end

      def self.to_string_attrs
        [:reuse, :volume_group_name]
      end
    end
  end
end
