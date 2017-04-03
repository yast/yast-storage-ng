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

require "y2storage/storage_class_wrapper"
require "y2storage/mountable"

module Y2Storage
  # A subvolume in a Btrfs filesystem
  #
  # This is a wrapper for Storage::BtrfsSubvolume
  class BtrfsSubvolume < Mountable
    wrap_class Storage::BtrfsSubvolume

    storage_forward :btrfs, as: "Filesystems::BlkDevice"
    alias_method :blk_filesystem, :btrfs
    alias_method :filesystem, :btrfs

    storage_forward :id
    storage_forward :top_level?
    storage_forward :top_level_btrfs_subvolume, as: "BtrfsSubvolume"
    storage_forward :path
    storage_forward :nocow?
    storage_forward :nocow=
    storage_forward :default_btrfs_subvolume?
    storage_forward :default_btrfs_subvolume=
    storage_forward :create_btrfs_subvolume, as: "BtrfsSubvolume"

  protected

    def types_for_is
      super << :btrfs_subvolume
    end
  end
end
