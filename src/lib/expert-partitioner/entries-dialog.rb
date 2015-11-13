
require "yast"
require "storage"
require "haha"

Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"
Yast.import "Directory"

module ExpertPartitioner

  class EntriesDialog

    include Yast::UIShortcuts
    include Yast::I18n
    include Yast::Logger


    def initialize
      textdomain "storage"

      @haha = Haha.new()

    end


    def run
      return unless create_dialog

      begin
        return event_loop
      ensure
        close_dialog
      end
    end


    private


    def create_dialog
      Yast::UI.OpenDialog(
        Opt(:decorated, :defaultsize),
        VBox(
          Heading(_("Disks and Partitions")),
          table,
          HBox(
            HWeight(1, PushButton(Id(:action), _("Action"))),
            HStretch(),
            HWeight(1, PushButton(Id(:cancel), Yast::Label.QuitButton))
          )
        )
      )
    end


    def close_dialog
      Yast::UI.CloseDialog
    end


    def event_loop
      loop do

        case Yast::UI.UserInput

        when :cancel
          break

        when :action
          do_action

        else
          log.warn "Unexpected input #{input}"
        end

      end
    end


    def table
      Table(
        Id(:entries_table),
        Header("Storage ID", "Icon", "Name", Right("Size"), "Partition Table", "Filesystem"),
        table_items
      )
    end


    def table_item(device)

      tmp = []

      begin
        tmp << device.sid
      end

      begin
        # ui shortcut for icon does not exist due to name collision
        if Storage::disk?(device)
          tmp << Cell(Yast::Term.new(:icon, Yast::Directory.icondir + "22x22/apps/yast-disk.png"), "Disk")
        elsif Storage::partition?(device)
          tmp << Cell(Yast::Term.new(:icon, Yast::Directory.icondir + "22x22/apps/yast-partitioning.png"), "Partition")
        else
          tmp << ""
        end
      end

      begin
        blk_device = Storage::to_blkdevice(device)
        tmp << blk_device.name
      rescue Storage::DeviceHasWrongType
        tmp << ""
      end

      begin
        blk_device = Storage::to_blkdevice(device)
        tmp << Storage::byte_to_humanstring(1024 * blk_device.size_k, false, 2, false)
      rescue Storage::DeviceHasWrongType
        tmp << ""
      end

      begin
        disk = Storage::to_disk(device)
        partition_table = disk.partition_table
        tmp << partition_table.to_s
      rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
        tmp << ""
      end

      begin
        blk_device = Storage::to_blkdevice(device)
        filesystem = blk_device.filesystem
        tmp << filesystem.to_s
      rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
        tmp << ""
      end

      Item(Id(device.sid), *tmp)

    end


    def table_items

      staging = @haha.storage().staging()

      ret = []

      disks = Storage::Disk::all(staging)

      disks.each do |disk|

        ret << table_item(disk)

        begin
          partition_table = disk.partition_table()
          partition_table.partitions().each do |partition|
            ret << table_item(partition)
          end
        rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
          log.info "not a partition table on #{disk.name}"
        end

      end

      return ret

    end


    def do_action

      sid = Yast::UI.QueryWidget(Id(:entries_table), :CurrentItem)

      staging = @haha.storage().staging()
      device = staging.find_device(sid)

      begin
        blk_device = Storage::to_blkdevice(device)
        log.info "do_action #{sid} #{blk_device.name}"
      rescue Storage::DeviceHasWrongType
        log.error "action on non blk device"
      end

    end

  end

end
