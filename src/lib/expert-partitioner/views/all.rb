
require "yast"
require "storage"
require "storage/storage-manager"
require "storage/extensions"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class AllView

    def create
      Table(
        Id(:table),
        Header("Storage ID", "Icon", "Name", Right("Size"), "Partition Table", "Filesystem", "Mount Point"),
        items
      )
    end

    def items

      storage = Yast::Storage::StorageManager.instance

      fields = [ :sid, :icon, :name, :size, :partition_table, :filesystem, :mountpoint ]

      staging = storage.staging()

      disks = Storage::Disk::all(staging)

      ret = []

      disks.each do |disk|

        ret << disk.table_row(fields)

        begin
          partition_table = disk.partition_table()
          partition_table.partitions().each do |partition|
            ret << partition.table_row(fields)
          end
        rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
        end

      end

      return ret

    end

  end

end
