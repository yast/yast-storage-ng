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

module Yast
  module Storage
    class Proposal
      # Each one of the spaces contained in a SpaceDistribution
      class AssignedSpace
        extend Forwardable

        # @return [FreeDiskSpace]
        attr_reader :disk_space
        # @return [PlannedVolumesList]
        attr_reader :volumes
        # @return [Symbol] :primary, :extended or nil.
        #   Spaces with a value of :primary should only contain primary partitions.
        #   Spaces with :extended should only contain logical (and eventually one
        #   extended) partitions.
        #   A value of nil means there are no restrictions imposed by the
        #   distribution (restrictions imposed by the disk itself still apply)
        attr_accessor :partition_type

        def_delegators :@disk_space, :disk_name, :size, :slot

        def initialize(disk_space, volumes)
          @disk_space = disk_space
          @volumes    = volumes
        end

        # Checks if the volumes really fit into the assigned space
        #
        # TODO: We do not check for start_offset. Anyways,
        #  - max_start_offset is usually a soft requirements (it may still work)
        #  - the chances of having 2 volumes with max_start_offset in the same
        #    free space are very low
        def valid?
          size >= volumes.target_size
        end

        # Space that will remain unused (wasted) after creating the partitions
        #
        # @return [DiskSize]
        def unused
          max = volumes.max_size
          max >= size ? 0 : size - max
        end

        def to_s
          "#<AssignedSpace disk_space=#{disk_space}, volumes=#{volumes}>"
        end
      end
    end
  end
end
