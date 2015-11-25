
require "yast"
require "storage"
require "haha"
require "storage/extensions"
require "expert-partitioner/format-dialog"

Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"
Yast.import "Directory"
Yast.import "HTML"


module ExpertPartitioner

  class EntriesDialog

    include Yast::UIShortcuts
    include Yast::I18n
    include Yast::Logger


    def initialize
      textdomain "storage"

      ExpertPartitioner.init()

      @haha = ExpertPartitioner.get_haha()

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
            HWeight(1, PushButton(Id(:cancel), Yast::Label.QuitButton)),
            HWeight(1, PushButton(Id(:commit), _("Commit")))
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

        when :commit
          if do_commit
            break
          end

        when :tree

          case current_item = Yast::UI.QueryWidget(:tree, :CurrentItem)

          when :all
            Yast::UI.ReplaceWidget(:tree_panel, table)

          when :filesystems
            Yast::UI.ReplaceWidget(:tree_panel, table_of_filesystems)

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

          when :actiongraph

            filename = "#{Yast::Directory.tmpdir}/actiongraph.gv"

            actiongraph = @haha.storage().calculate_actiongraph()
            actiongraph.write_graphviz(filename)

            Yast::UI.ReplaceWidget(
              :tree_panel,
              VBox(
                Heading(_("Action Graph")),
                Yast::Term.new(:Graph, Id(:graph), Opt(:notify, :notifyContextMenu), filename, "dot"),
              )
            )

          when :actionlist

            actiongraph = @haha.storage().calculate_actiongraph()

            steps = actiongraph.commit_actions_as_strings()

            texts = []
            steps.each { |step| texts << step }

            Yast::UI.ReplaceWidget(
              :tree_panel,
              VBox(
                Heading(_("Installation Steps")),
                RichText(Yast::HTML.List(texts)),
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
        Item(Id(:filesystems), _("Filesystems")),
        Item(Id(:devicegraph_probed), _("Device Graph (probed)")),
        Item(Id(:devicegraph_staging), _("Device Graph (staging)")),
        Item(Id(:actiongraph), _("Action Graph")),
        Item(Id(:actionlist), _("Action List"))
      ]
    end


    def table
      Table(
        Id(:table),
        Header("Storage ID", "Icon", "Name", Right("Size"), "Partition Table", "Filesystem", "Mount Point"),
        table_items
      )
    end


    def table_items

      fields = [ :sid, :icon, :name, :size, :partition_table, :filesystem, :mountpoint ]

      staging = @haha.storage().staging()

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



    def table_of_filesystems
      Table(
        Id(:table),
        Header("Storage ID", "Icon", "Filesystem", "Mount Point", "Label"),
        table_of_filesystems_items
      )
    end


    def table_of_filesystems_items

      fields = [ :sid, :icon, :filesystem, :mountpoint, :label ]

      staging = @haha.storage().staging()

      filesystems = Storage::Filesystem::all(staging)

      ret = []

      filesystems.each do |filesystem|
        ret << filesystem.table_row(fields)
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


    def do_commit

      actiongraph = @haha.storage().calculate_actiongraph()

      if actiongraph.empty?
        Yast::Popup::Error("Nothing to commit.")
        return false
      end
      if !Yast::Popup::YesNo("Really commit?")
        return false
      end

      @haha.storage().calculate_actiongraph()
      @haha.storage().commit()

      return true

    end

  end

end
