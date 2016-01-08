
require "yast"
require "storage"
require "storage/storage-manager"
require "storage/extensions"
require "expert-partitioner/tree-views/view"
require "expert-partitioner/dialogs/format"
require "expert-partitioner/dialogs/create-partition-table"
require "expert-partitioner/dialogs/create-partition"
require "expert-partitioner/popups"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger


module ExpertPartitioner

  class MdsTreeView < TreeView

    FIELDS = [ :sid, :icon, :name, :size, :md_level, :partition_table, :filesystem, :mountpoint ]


    def initialize()
      storage = Yast::Storage::StorageManager.instance
      staging = storage.staging()
      @mds = staging.all_mds()
    end


    def create
      VBox(
        Left(IconAndHeading(_("MD RAIDs"), Icons::MD)),
        Table(Id(:table), Opt(:keepSorting), Storage::Device.table_header(FIELDS), items),
        HBox(
          PushButton(Id(:create), _("Create...")),
          PushButton(Id(:format), _("Format...")),
          PushButton(Id(:delete), _("Delete...")),
          HStretch()
        )
      )
    end


    def handle(input)

      case input

      when :create
        do_create_partition

      when :format
        do_format

      when :delete
        do_delete_partition

      when :create_partition_table
        do_create_partition_table

      end

    end


    private


    def items

      ret = []

      ::Storage::silence do

        @mds.each do |md|

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


    def do_create_partition

      begin
        partition_table = @md.partition_table()
      rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
        Yast::Popup::Error("Md has no partition table.")
        return
      end

      CreatePartitionDialog.new(@md).run()

      update(true)

    end


    def do_format

      sid = Yast::UI.QueryWidget(Id(:table), :CurrentItem)

      storage = Yast::Storage::StorageManager.instance
      staging = storage.staging()
      device = staging.find_device(sid)

      begin
        blk_device = Storage::to_blk_device(device)
        log.info "do_format #{sid} #{blk_device.name}"
        FormatDialog.new(blk_device).run()
      rescue Storage::DeviceHasWrongType
        log.error "do_format on non blk device"
      end

      update(true)

    end


    def do_delete_partition

      sid = Yast::UI.QueryWidget(Id(:table), :CurrentItem)

      storage = Yast::Storage::StorageManager.instance
      staging = storage.staging()

      device = staging.find_device(sid)

      begin
        partition = Storage::to_partition(device)
      rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
        Yast::Popup::Error("Only partitions can be deleted.")
        return
      end

      if RemoveDescendantsPopup.new(partition).run()
        staging.remove_device(partition)
        update(true)
      end

    end


    def do_create_partition_table

      CreatePartitionTableDialog.new(@md).run()

      update(true)

    end


  end

end
