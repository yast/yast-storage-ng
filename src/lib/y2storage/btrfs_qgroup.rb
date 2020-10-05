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

    # @attr :rfer_limit
    #   @return [DiskSize,nil] Referenced extents quota (shared quota). `nil` if not set.
    attr_reader :rfer_limit

    # @attr :excl_limit
    #   @return [DiskSize,nil] Exclusive extents quota. `nil` if not set.
    attr_reader :excl_limit

    # Constructor
    #
    # @param subvol_id [Integer] Subvolume ID
    # @param rfer_limit [DiskSize,nil] Referenced extents limit
    # @param excl_limit [DiskSize,nil] Exclusive extents limit
    def initialize(subvol_id, rfer_limit = nil, excl_limit = nil)
      @subvol_id = subvol_id
      @rfer_limit = rfer_limit
      @excl_limit = excl_limit
    end
  end
end
