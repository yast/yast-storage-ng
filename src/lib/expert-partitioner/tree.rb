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
            Item(Id(:disks), _("Hard Disks"), true, disks_subtree_items()),
            Item(Id(:mds), _("MD RAIDs"), true, mds_subtree_items()),
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
      staging = storage.staging()

      disks = Storage::Disk::all(staging)

      ::Storage::silence do

        return disks.to_a.map do |disk|

          partitions_subtree = []

          begin
            partition_table = disk.partition_table()
            partition_table.partitions().each do |partition|
              partitions_subtree << Item(Id(partition.sid()), partition.name())
            end
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
          end

          Item(Id(disk.sid()), disk.name(), true, partitions_subtree)

        end

      end

    end


    def mds_subtree_items

      storage = Yast::Storage::StorageManager.instance
      staging = storage.staging()

      mds = Storage::Md::all(staging)

      ::Storage::silence do

        return mds.to_a.map do |md|

          partitions_subtree = []

          begin
            partition_table = md.partition_table()
            partition_table.partitions().each do |partition|
              partitions_subtree << Item(Id(partition.sid()), partition.name())
            end
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
          end

          Item(Id(md.sid()), md.name(), true, partitions_subtree)

        end

      end

    end

  end

end
