# Copyright (c) [2020] SUSE LLC
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

module Y2Storage
  # Class that represents a Btrfs Quota Groups
  #
  # In Btrfs, the Qgroups hold the quota information for a given set of
  # subvolumes. Although they can be organized in a tree hierarchy, we are
  # only considering the first level (level 0, actually), so they are
  # associated to a single subvolume.
  #
  # @see man btrfs-qgroup
  class BtrfsQgroup
    attr_reader :subvol_id

    # @attr :max_referenced
    #   @return [DiskSize,nil] Referenced extents quota (shared quota). `nil` if not set.
    attr_reader :max_referenced

    # @attr :max_exclusive
    #   @return [DiskSize,nil] Exclusive extents quota. `nil` if not set.
    attr_reader :max_exclusive

    # Constructor
    #
    # @param subvol_id [Integer] Subvolume ID
    # @param max_referenced [DiskSize,nil] Referenced extents limit
    # @param max_exclusive [DiskSize,nil] Exclusive extents limit
    def initialize(subvol_id, max_referenced = nil, max_exclusive = nil)
      @subvol_id = subvol_id
      @max_referenced = max_referenced
      @max_exclusive = max_exclusive
    end
  end
end
