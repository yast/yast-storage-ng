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
