
require "yast"
require "storage"
require "storage/storage-manager"
require "storage/extensions"
require "expert-partitioner/views/view"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class DiskView < View

    FIELDS = [ :sid, :icon, :name, :size, :transport, :partition_table, :filesystem, :mountpoint ]

    def initialize(disk)
      @disk = disk
    end

    def create
      Table(Id(:table), Storage::Device.table_header(FIELDS), items)
    end

    def items

      storage = Yast::Storage::StorageManager.instance

      staging = storage.staging()

      ret = []

      ret << @disk.table_row(FIELDS)

      begin
        partition_table = @disk.partition_table()
        partition_table.partitions().each do |partition|
          ret << partition.table_row(FIELDS)
        end
      rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
      end

      return ret

    end

  end

end
