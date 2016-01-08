
require "yast"
require "storage"
require "storage/storage-manager"
require "storage/extensions"
require "expert-partitioner/tree-views/view"
require "expert-partitioner/icons"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class AllTreeView < TreeView

    FIELDS = [ :sid, :icon, :name, :size, :partition_table, :filesystem, :mountpoint ]

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

      staging = storage.staging()

      ret = []

      disks = Storage::Disk::all(staging)

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

      mds = Storage::Md::all(staging)

      ::Storage::silence do

        mds.each do |md|

          ret << md.table_row(FIELDS)

          begin
            partition_table = md.partition_table()
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
