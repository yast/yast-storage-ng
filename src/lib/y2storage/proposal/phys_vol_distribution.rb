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

require "y2storage/disk_size"

module Y2Storage
  class Proposal
    # A possible distribution of LVM physical volumes among a set of free
    # spaces.
    #
    # Used by SpaceDistribution to propose all the possibilities of creating
    # physical volumes.
    class PhysVolDistribution
      include Enumerable
      extend Forwardable

      def initialize(volumes_by_space)
        @volumes = volumes_by_space
      end

      def_delegators :@volumes, :each, :each_pair, :empty?, :length, :size

      def ==(other)
        self.class == other.class && internal_state == other.internal_state
      end

    protected

      def internal_state
        @volumes
      end

      class << self
        # All possible distributions of physical volumes in a given set of disk
        # spaces.
        #
        # @param space_sizes [Hash{FreeDiskSpace => DiskSize}] As keys, all the
        #     spaces that could potentially contain a PV. As values the max size
        #     of such PV, since some space could already be reserved for other
        #     (no LVM) planned volumes.
        # @param needed_total_size [DiskSize]
        # @param max_total_size [DiskSize]
        #
        # @return [Array<PhysVolDistribution>]
        def all(space_sizes, needed_total_size, max_total_size)
          all = []
          all_spaces = space_sizes.keys
          all_spaces.permutation.each do |sorted_spaces|
            distribution = new_for_order(sorted_spaces, space_sizes, needed_total_size, max_total_size)
            next unless distribution

            all << distribution unless all.include?(distribution)
          end
          all
        end

      protected

        # Returns a new PhysVolDistribution created by assigning a physical volume
        # to each space, following the given order, until the goal is reached.
        # Returns nil if it's not possible to create a distribution of physical
        # volumes that warrants needed_total_size.
        #
        # @param sorted_spaces [Array<FreeDiskSpace>]
        # @param max_sizes [Hash{FreeDiskSpace => DiskSize}] for every space,
        #     the max size usable for creating a physical volume
        # @param needed_total_size [DiskSize]
        # @param max_total_size [DiskSize]
        #
        # @return [PhysVolDistribution, nil]
        def new_for_order(sorted_spaces, max_sizes, needed_total_size, max_total_size)
          volumes = {}
          missing_size = needed_total_size

          sorted_spaces.each do |space|
            usable_size = max_sizes[space]
            next unless usable_size > DiskSize.zero

            pv_vol = new_planned_volume
            volumes[space] = pv_vol

            if usable_size < missing_size
              # Still not enough, let's use the whole space
              pv_vol.min_disk_size = pv_vol.desired_disk_size = usable_size
              pv_vol.max_disk_size = usable_size
              missing_size -= usable_size
            else
              # This space is the last one we need to fill
              pv_vol.min_disk_size = pv_vol.desired_disk_size = missing_size
              other_vols_size = needed_total_size - missing_size
              pv_vol.max_disk_size = max_total_size - other_vols_size
              missing_size = DiskSize.zero
              break
            end
          end

          return nil unless missing_size.zero?
          new(volumes)
        end

        # Volume representing a LVM physical volume
        #
        # @return [PlannedVolume]
        def new_planned_volume
          res = PlannedVolume.new(nil)
          res.partition_id = ::Storage::ID_LVM
          res
        end
      end
    end
  end
end
