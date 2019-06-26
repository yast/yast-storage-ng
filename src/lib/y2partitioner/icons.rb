# Copyright (c) [2017-2019] SUSE LLC
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

Yast.import "Directory"

module Y2Partitioner
  # Icons used by partitioner
  module Icons
    # icon
    ALL = "computer".freeze

    # icon
    HD = "drive-harddisk".freeze

    # icon
    HD_PART = "drive-partition".freeze

    # icon
    LVM = "drive-multipartition".freeze
    # icon
    LVM_LV = HD_PART

    # icon
    RAID = "drive-multidisk".freeze

    # icon
    LOOP = HD

    # icon
    DM = "view-list-tree".freeze

    # icon
    MULTIPATH = DM

    # icon
    NFS = "folder-remote".freeze

    # icon
    BTRFS = LVM

    # icon
    UNUSED = "emblem-warning".freeze

    # icon
    GRAPH = DM

    # icon
    SUMMARY = "view-list".freeze

    # icon
    SETTINGS = "configure".freeze

    # icon
    LOG = "view-list-text".freeze

    # icon
    ENCRYPTED = "drive-harddisk-encrypted".freeze

    # Default device icon
    DEFAULT_DEVICE = "media-removable".freeze

    # icon
    BCACHE = HD

    LOCK = "lock".freeze

    ISCSI = "drive-iscsi".freeze

    FCOE = "drive-fcoe".freeze

    DASD = "drive-dasd".freeze

    ZFCP = "drive-zfcp".freeze

    XPRAM = "drive-xpram".freeze
  end
end
