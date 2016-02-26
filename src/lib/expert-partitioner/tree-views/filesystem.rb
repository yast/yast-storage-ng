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
require "storage/storage-manager"
require "storage/extensions"
require "expert-partitioner/tree-views/view"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class FilesystemTreeView < TreeView

    FIELDS = [ :sid, :icon, :filesystem, :mountpoint, :mount_by, :label ]

    def create
      VBox(
        Left(IconAndHeading(_("Filesystems"), Icons::FILESYSTEM)),
        Table(Id(:table), Opt(:keepSorting), Storage::Device.table_header(FIELDS), items)
      )
    end

    def items

      storage = Yast::Storage::StorageManager.instance
      staging = storage.staging()

      filesystems = Storage::Filesystem::all(staging)

      return filesystems.to_a.map do |filesystem|
        filesystem.table_row(FIELDS)
      end

    end

  end

end
