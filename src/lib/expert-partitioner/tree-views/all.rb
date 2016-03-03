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
require "expert-partitioner/tree-views/view"
require "expert-partitioner/icons"

Yast.import "UI"

include Yast::I18n

module ExpertPartitioner
  class AllTreeView < TreeView
    FIELDS = [:sid, :icon, :name, :size, :partition_table, :filesystem, :mountpoint]

    def create
      VBox(
        Left(IconAndHeading(_("Storage"), Icons::ALL)),
        Table(Id(:table), Opt(:keepSorting), Storage::Device.table_header(FIELDS), items),
        HBox(
          PushButton(Id(:rescan), _("Rescan Devices")),
          HStretch(),
          PushButton(Id(:configure), _("Configure..."))
        )
      )
    end

    def items
      storage = Yast::Storage::StorageManager.instance

      staging = storage.staging

      ret = []

      disks = Storage::Disk.all(staging)

      ::Storage.silence do

        disks.each do |disk|

          ret << disk.table_row(FIELDS)

          begin
            partition_table = disk.partition_table
            partition_table.partitions.each do |partition|
              ret << partition.table_row(FIELDS)
            end
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
          end

        end

      end

      mds = Storage::Md.all(staging)

      ::Storage.silence do

        mds.each do |md|

          ret << md.table_row(FIELDS)

          begin
            partition_table = md.partition_table
            partition_table.partitions.each do |partition|
              ret << partition.table_row(FIELDS)
            end
          rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
          end

        end

      end

      return ret
    end
  end
end
