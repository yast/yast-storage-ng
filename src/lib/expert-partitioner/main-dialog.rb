
require "yast"
require "storage"
require "storage/storage-manager"
require "storage/extensions"
require "expert-partitioner/format-dialog"
require "expert-partitioner/views/all"
require "expert-partitioner/views/disk"
require "expert-partitioner/views/partition"
require "expert-partitioner/views/filesystem"
require "expert-partitioner/views/probed-devicegraph"
require "expert-partitioner/views/staging-devicegraph"
require "expert-partitioner/views/actiongraph"
require "expert-partitioner/views/actionlist"

Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"
Yast.import "Directory"
Yast.import "HTML"

include Yast::I18n


module ExpertPartitioner

  class MainDialog

    include Yast::UIShortcuts
    include Yast::Logger


    def initialize
      textdomain "storage"
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

      @view = AllView.new()
      Yast::UI.ReplaceWidget(:tree_panel, @view.create)

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
            @view = AllView.new()

          when :hd
            @view = AllView.new()

          when :filesystems
            @view = FilesystemView.new()

          when :devicegraph_probed
            @view = ProbedDevicegraphView.new()

          when :devicegraph_staging
            @view = StagingDevicegraphView.new()

          when :actiongraph
            @view = ActiongraphView.new()

          when :actionlist
            @view = ActionlistView.new()

          else

            sid = current_item

            storage = Yast::Storage::StorageManager.instance
            staging = storage.staging()

            device = staging.find_device(sid)

            if Storage::disk?(device)
              @view = DiskView.new(Storage::to_disk(device))
            elsif Storage::partition?(device)
              @view = PartitionView.new(Storage::to_partition(device))
            end

          end

          Yast::UI.ReplaceWidget(:tree_panel, @view.create)

        else
          log.warn "Unexpected input #{input}"
        end

      end
    end


    def tree
      Tree(Id(:tree), Opt(:notify), _("System View"), [
             Item(
               Id(:all), "hostname", true,
               [
                 Item(Id(:hd), _("Hard Disks"), false, disks_subtree()),
                 Item(Id(:filesystems), _("Filesystems"))
               ]
             ),
             Item(Id(:devicegraph_probed), _("Device Graph (probed)")),
             Item(Id(:devicegraph_staging), _("Device Graph (staging)")),
             Item(Id(:actiongraph), _("Action Graph")),
             Item(Id(:actionlist), _("Action List"))
           ])
    end


    def disks_subtree

      storage = Yast::Storage::StorageManager.instance
      staging = storage.staging()

      disks = Storage::Disk::all(staging)

      return disks.to_a.map do |disk|

        partitions_subtree = []

        begin
          partition_table = disk.partition_table()
          partition_table.partitions().each do |partition|
            partitions_subtree << Item(Id(partition.sid()), partition.name())
          end
        rescue Storage::WrongNumberOfChildren, Storage::DeviceHasWrongType
        end

        Item(Id(disk.sid()), disk.name(), partitions_subtree)

      end

    end


    def do_format

      sid = Yast::UI.QueryWidget(Id(:table), :CurrentItem)

      storage = Yast::Storage::StorageManager.instance
      staging = storage.staging()
      device = staging.find_device(sid)

      begin
        blk_device = Storage::to_blk_device(device)
        log.info "do_format #{sid} #{blk_device.name}"
      rescue Storage::DeviceHasWrongType
        log.error "do_format on non blk device"
      end

      FormatDialog.new(sid).run()

      Yast::UI.ReplaceWidget(:tree_panel, @view.create)

    end


    def do_commit

      storage = Yast::Storage::StorageManager.instance
      actiongraph = storage.calculate_actiongraph()

      if actiongraph.empty?
        Yast::Popup::Error("Nothing to commit.")
        return false
      end
      if !Yast::Popup::YesNo("Really commit?")
        return false
      end

      storage.calculate_actiongraph()
      storage.commit()

      return true

    end

  end

end
