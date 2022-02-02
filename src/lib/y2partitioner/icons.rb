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
    # Name of the icon
    ALL = "computer".freeze

    # Name of the icon
    HD = "drive-harddisk".freeze

    # Name of the icon
    HD_PART = "drive-partition".freeze

    # Name of the icon
    LVM = "drive-multipartition".freeze

    # Name of the icon
    LVM_LV = HD_PART

    # Name of the icon
    RAID = "drive-multidisk".freeze

    # Name of the icon
    LOOP = HD

    # Name of the icon
    DM = "view-list-tree".freeze

    # Name of the icon
    MULTIPATH = DM

    # Name of the icon
    NFS = "folder-remote".freeze

    # Name of the icon
    BTRFS = LVM

    # Name of the icon
    TMPFS = "folder-temp".freeze

    # Name of the icon
    UNUSED = "emblem-warning".freeze

    # Name of the icon
    GRAPH = DM

    # Name of the icon
    SUMMARY = "view-list".freeze

    # Name of the icon
    SETTINGS = "configure".freeze

    # Name of the icon
    LOG = "view-list-text".freeze

    # Name of the icon
    ENCRYPTED = "drive-harddisk-encrypted".freeze

    # Default device icon
    DEFAULT_DEVICE = "media-removable".freeze

    # Name of the icon
    BCACHE = HD

    # Name of the icon
    LOCK = "lock".freeze

    # Name of the icon
    ISCSI = "drive-iscsi".freeze

    # Name of the icon
    FCOE = "drive-fcoe".freeze

    # Name of the icon
    DASD = "drive-dasd".freeze

    # Name of the icon
    ZFCP = "drive-zfcp".freeze

    # Name of the icon
    XPRAM = "drive-xpram".freeze
  end
end
