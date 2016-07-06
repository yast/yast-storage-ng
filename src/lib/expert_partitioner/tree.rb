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
require "storage"
require "storage/storage_manager"
require "storage/extensions"

Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"
Yast.import "Directory"
Yast.import "HTML"

include Yast::I18n

module ExpertPartitioner
  # Class to hold the items to be displayed as a three in the UI
  class Tree
    include Yast::UIShortcuts
    include Yast::Logger

    def initialize
      textdomain "storage"
    end

    def tree_items
      [
        Item(
          Id(:all), "hostname", true,
          [
            Item(Id(:disks), _("Hard Disks"), true, disks_subtree_items),
            Item(Id(:mds), _("MD RAIDs"), true, mds_subtree_items),
            Item(Id(:lvm_vgs), _("LVM VGs"), true, lvm_vgs_subtree_items),
            Item(Id(:lukses), _("LUKSes"), true, lukses_subtree_items),
            Item(Id(:bcaches), _("Bcaches"), true, bcaches_subtree_items),
            Item(Id(:bcache_csets), _("Bcache Csets"), true, bcache_csets_subtree_items),
            Item(Id(:filesystems), _("Filesystems"))
          ]
        ),
        Item(Id(:devicegraph_probed), _("Device Graph (probed)")),
        Item(Id(:devicegraph_staging), _("Device Graph (staging)")),
        Item(Id(:actiongraph), _("Action Graph")),
        Item(Id(:actionlist), _("Action List"))
      ]
    end

  private

    def disks_subtree_items
      storage = Yast::Storage::StorageManager.instance

      disks = Storage::Disk.all(storage.staging)

      ::Storage.silence do

        return disks.to_a.map do |disk|

          partitions_subtree = []

          begin
            partition_table = disk.partition_table
            partition_table.partitions.each do |partition|
              partitions_subtree << Item(Id(partition.sid), partition.name)
            end
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
          end

          Item(Id(disk.sid), disk.name, true, partitions_subtree)

        end

      end
    end

    def mds_subtree_items
      storage = Yast::Storage::StorageManager.instance

      mds = Storage::Md.all(storage.staging)

      ::Storage.silence do

        return mds.to_a.map do |md|

          partitions_subtree = []

          begin
            partition_table = md.partition_table
            partition_table.partitions.each do |partition|
              partitions_subtree << Item(Id(partition.sid), partition.name)
            end
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
          end

          Item(Id(md.sid), md.name, true, partitions_subtree)

        end

      end
    end

    def lvm_vgs_subtree_items
      storage = Yast::Storage::StorageManager.instance

      lvm_vgs = Storage::LvmVg.all(storage.staging)

      return lvm_vgs.to_a.map do |lvm_vg|

        lvm_lvs_subtree = []

        lvm_vg.lvm_lvs.each do |lvm_lv|
          lvm_lvs_subtree << Item(Id(lvm_lv.sid), lvm_lv.lv_name)
        end

        Item(Id(lvm_vg.sid), lvm_vg.vg_name, true, lvm_lvs_subtree)

      end
    end

    def lukses_subtree_items
      storage = Yast::Storage::StorageManager.instance

      lukses = Storage::Luks.all(storage.staging)

      return lukses.to_a.map do |luks|
        Item(Id(luks.sid), luks.dm_table_name, true)
      end
    end

    def bcaches_subtree_items
      storage = Yast::Storage::StorageManager.instance

      bcaches = Storage::Bcache.all(storage.staging)

      return bcaches.to_a.map do |bcache|
        Item(Id(bcache.sid), bcache.name, true)
      end
    end

    def bcache_csets_subtree_items
      storage = Yast::Storage::StorageManager.instance

      bcache_csets = Storage::BcacheCset.all(storage.staging)

      return bcache_csets.to_a.map do |bcache_cset|
        Item(Id(bcache_cset.sid), bcache_cset.uuid, true)
      end
    end
  end
end
