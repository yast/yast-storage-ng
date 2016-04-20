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

require "fileutils"
require "storage/planned_volumes_list"
require "storage/disk_size"
require "storage/refinements/devicegraph"
require "storage/refinements/devicegraph_lists"

module Yast
  module Storage
    class Proposal
      # Class to distribute sets of planned volumes into sets of free
      # disk spaces
      class VolumesDispatcher
        FREE_SPACE_MIN_SIZE = DiskSize.MiB(30)

        # Initialize.
        #
        # @param settings [Proposal::Settings] proposal settings
        def initialize(settings)
          @settings = settings
        end

        # Distributes volumes among the free spaces
        #
        # Eventually, we could do different attempts inside the method with
        # different approaches.
        #
        # @raise NoDiskSpaceError if it's not unable to do the matching
        #
        # @param volumes [PlannedVolumesList]
        # @param free_spaces [Array<FreeDiskSpace>]
        # @param target_size [Symbol] :desired or :min
        #
        # @return [Hash{FreeDiskSpace => PlannedVolumesList]
        def distribution(volumes, free_spaces, target_size)
          raise NotImplementedError
        end

        # Additional space that would be needed in order to maximize the
        # posibilities of #distribution to succeed.
        #
        # This is tricky, because it's not just a matter of size
        #
        # Used when resizing windows (in order to know how much space to remove
        # from the partition), so maybe we can rethink this a little bit in the
        # future if needed
        def missing_size(volumes, free_spaces, target_size)
          raise NotImplementedError
        end

      protected

        def useful_spaces(free_spaces, volumes)
          if settings.use_lvm
            free_spaces.select do |space|
              space.size >= FREE_SPACE_MIN_SIZE
            end
          else
            free_spaces.select do |space|
              space.size >= smaller_volume(volumes, target_size)
            end
          end
        end
      end
    end
  end
end
