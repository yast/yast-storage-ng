
require "yast"
require "storage"
require "storage/storage-manager"
require "storage/extensions"
require "expert-partitioner/tree"
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

      @view = AllView.new()

      Yast::UI.OpenDialog(
        Opt(:decorated, :defaultsize),
        VBox(
          Heading(_("Disks and Partitions")),
          HBox(
            HWeight(30, Tree(Id(:tree), Opt(:notify), _("System View"), Tree.new().tree_items)),
            HWeight(70, ReplacePoint(Id(:tree_panel), @view.create()))
          ),
          HBox(
            HStretch(),
            PushButton(Id(:cancel), Yast::Label.QuitButton),
            PushButton(Id(:commit), _("Commit"))
          )
        )
      )

    end


    def close_dialog
      Yast::UI.CloseDialog
    end


    def event_loop
      loop do

        input = Yast::UI.UserInput

        @view.handle(input)

        case input

        when :cancel
          break

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

          @view.update()

        else
          log.warn "Unexpected input #{input}"
        end

      end
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
