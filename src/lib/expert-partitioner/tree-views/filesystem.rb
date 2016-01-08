
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
