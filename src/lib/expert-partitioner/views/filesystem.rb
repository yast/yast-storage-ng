
require "yast"
require "storage"
require "storage/storage-manager"
require "storage/extensions"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class FilesystemView

    def create
      Table(
        Id(:table),
        Header("Storage ID", "Icon", "Filesystem", "Mount Point", "Label"),
        items
      )
    end

    def items

      storage = Yast::Storage::StorageManager.instance

      fields = [ :sid, :icon, :filesystem, :mountpoint, :label ]

      staging = storage.staging()

      filesystems = Storage::Filesystem::all(staging)

      ret = []

      filesystems.each do |filesystem|
        ret << filesystem.table_row(fields)
      end

      return ret

    end

  end

end
