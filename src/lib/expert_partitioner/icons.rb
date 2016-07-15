# encoding: utf-8

# Copyright (c) [2015-2016] SUSE LLC
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

module ExpertPartitioner
  class Icons
    ALL = "yast-disk.png".freeze

    DEVICE = "yast-disk.png".freeze

    DISK = "yast-disk.png".freeze

    MD = "yast-raid.png".freeze

    LVM_PV = "yast-disk.png".freeze
    LVM_VG = "yast-lvm_config.png".freeze
    LVM_LV = "yast-partitioning.png".freeze

    PARTITION = "yast-partitioning.png".freeze

    ENCRYPTION = "yast-encrypted.png".freeze

    BCACHE = "yast-disk.png".freeze
    BCACHE_CSET = "yast-disk.png".freeze

    FILESYSTEM = "yast-nfs.png".freeze
  end
end
