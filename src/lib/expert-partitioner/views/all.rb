
require "yast"
require "storage"
require "storage/storage-manager"
require "storage/extensions"
require "expert-partitioner/views/view"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class AllView < View

    FIELDS = [ :sid, :icon, :name, :size, :transport, :partition_table, :filesystem, :mountpoint ]

    def create
      VBox(
        Table(Id(:table), Storage::Device.table_header(FIELDS), items),
        HBox(
          PushButton(Id(:rescan), _("Rescan Devices")),
          HStretch(),
          PushButton(Id(:configure), _("Configure..."))
        )
      )
    end

    def items

      storage = Yast::Storage::StorageManager.instance

      staging = storage.staging()

      disks = Storage::Disk::all(staging)

      ret = []

      ::Storage::silence do

        disks.each do |disk|

          ret << disk.table_row(FIELDS)

          begin
            partition_table = disk.partition_table()
            partition_table.partitions().each do |partition|
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
