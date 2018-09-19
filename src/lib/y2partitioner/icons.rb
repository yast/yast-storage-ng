require "yast"

Yast.import "Directory"

module Y2Partitioner
  # Icons used by partitioner
  module Icons
    # icon
    ALL = "yast-disk.png".freeze

    # icon
    HD = "yast-disk.png".freeze

    # icon
    HD_PART = "yast-partitioning.png".freeze

    # icon
    LVM = "yast-lvm_config.png".freeze
    # icon
    LVM_LV = "yast-partitioning.png".freeze

    # icon
    RAID = "yast-raid.png".freeze

    # icon
    LOOP = "yast-encrypted.png".freeze

    # icon
    DM = "yast-device-mapper.png".freeze

    # icon
    MULTIPATH = DM

    # icon
    NFS = "yast-nfs.png".freeze

    # icon
    BTRFS = NFS

    # icon
    UNUSED = "yast-unused-device.png".freeze

    # icon
    GRAPH = "yast-device-tree.png".freeze

    # icon
    SUMMARY = "yast-disk.png".freeze

    # icon
    SETTINGS = "yast-spanner.png".freeze

    # icon
    LOG = "yast-messages.png".freeze

    # icon
    ENCRYPTED = "yast-encrypted.png".freeze

    # Default device icon
    DEFAULT_DEVICE = "yast-hdd-controller-kernel-module.png".freeze

    # icon
    BCACHE = HD

    # path to small icons, fits nicely in table
    SMALL_ICONS_PATH = (Yast::Directory.icondir + "22x22/apps/").freeze

    # helper to get full path to small version of icon
    # @param icon [String] icon filename including suffix
    def self.small_icon(icon)
      SMALL_ICONS_PATH + icon
    end
  end
end
