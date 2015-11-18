
require "yast"
require "storage"
require "haha"
require "expert-partitioner/format-dialog.rb"

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
          HBox(
            HWeight(30, tree),
            HWeight(70, ReplacePoint(Id(:tree_panel), VBox(VStretch(), HStretch())))
          ),
          HBox(
            HStretch(),
            HWeight(1, PushButton(Id(:format), _("Format"))),
            HWeight(1, PushButton(Id(:cancel), Yast::Label.QuitButton))
          )
        )
      )
      Yast::UI.ReplaceWidget(:tree_panel, table)
    end


    def close_dialog
      Yast::UI.CloseDialog
    end


    def event_loop
      loop do

        case input = Yast::UI.UserInput

        when :cancel
          break

        when :format
          do_format

        when :tree

          case current_item = Yast::UI.QueryWidget(:tree, :CurrentItem)

          when :all
            Yast::UI.ReplaceWidget(:tree_panel, table)

          when :devicegraph_probed

            filename = "#{Yast::Directory.tmpdir}/devicegraph-probed.gv"

            probed = @haha.storage().probed()
            probed.write_graphviz(filename)

            Yast::UI.ReplaceWidget(
              :tree_panel,
              VBox(
                Heading(_("Device Graph (probed)")),
                Yast::Term.new(:Graph, Id(:graph), Opt(:notify, :notifyContextMenu), filename, "dot"),
              )
            )

          when :devicegraph_staging

            filename = "#{Yast::Directory.tmpdir}/devicegraph-staging.gv"

            staging = @haha.storage().staging()
            staging.write_graphviz(filename)

            Yast::UI.ReplaceWidget(
              :tree_panel,
              VBox(
                Heading(_("Device Graph (staging)")),
                Yast::Term.new(:Graph, Id(:graph), Opt(:notify, :notifyContextMenu), filename, "dot"),
              )
            )

          end

        else
          log.warn "Unexpected input #{input}"
        end

      end
    end


    def tree
      Tree(Id(:tree), Opt(:notify), _("System View"), tree_items)
    end


    def subtree

      staging = @haha.storage().staging()

      ret = []

      disks = Storage::Disk::all(staging)

      disks.each do |disk|

        s = []

        begin
          partition_table = disk.partition_table()
          partition_table.partitions().each do |partition|
            s << Item(Id(partition.sid()), partition.name())
          end
        rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
        end

        ret << Item(Id(disk.sid()), disk.name(), s)

      end

      return ret

    end


    def tree_items
      [
        Item(
          Id(:all), "hostname", true,
          [
            Item(
              Id(:hd), _("Hard Disks"), false,
              subtree()
            )
          ]
        ),
        Item(Id(:devicegraph_probed), _("Device Graph (probed)")),
        Item(Id(:devicegraph_staging), _("Device Graph (staging)")),
        Item(Id(:actiongraph), _("Action Graph")),
        Item(Id(:actionlist), _("Action List"))
      ]
    end


    def table
      Table(
        Id(:table),
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
        end

      end

      return ret

    end


    def do_format

      sid = Yast::UI.QueryWidget(Id(:table), :CurrentItem)

      staging = @haha.storage().staging()
      device = staging.find_device(sid)

      begin
        blk_device = Storage::to_blkdevice(device)
        log.info "do_format #{sid} #{blk_device.name}"
      rescue Storage::DeviceHasWrongType
        log.error "do_format on non blk device"
      end

      FormatDialog.new(sid).run()

    end

  end

end
