# encoding: utf-8

# Copyright (c) [2015] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"
require "storage"
require "storage/storage_manager"
require "storage/extensions"
require "expert_partitioner/tree"
require "expert_partitioner/tree_views/all"
require "expert_partitioner/tree_views/disks"
require "expert_partitioner/tree_views/disk"
require "expert_partitioner/tree_views/mds"
require "expert_partitioner/tree_views/md"
require "expert_partitioner/tree_views/partition"
require "expert_partitioner/tree_views/filesystem"
require "expert_partitioner/tree_views/probed_devicegraph"
require "expert_partitioner/tree_views/staging_devicegraph"
require "expert_partitioner/tree_views/actiongraph"
require "expert_partitioner/tree_views/actionlist"

Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"
Yast.import "Directory"
Yast.import "HTML"

include Yast::I18n

module ExpertPartitioner
  # Main UI dialog of the expert partitioner prototype
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
      @view = AllTreeView.new

      Yast::UI.OpenDialog(
        Opt(:decorated, :defaultsize),
        VBox(
          Left(Heading(_("Expert Partitioner"))),
          HBox(
            HWeight(30, Tree(Id(:tree), Opt(:notify), _("System View"), Tree.new.tree_items)),
            HWeight(70, ReplacePoint(Id(:tree_panel), @view.create))
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
            @view = AllTreeView.new

          when :disks
            @view = DisksTreeView.new

          when :mds
            @view = MdsTreeView.new

          when :filesystems
            @view = FilesystemTreeView.new

          when :devicegraph_probed
            @view = ProbedDevicegraphTreeView.new

          when :devicegraph_staging
            @view = StagingDevicegraphTreeView.new

          when :actiongraph
            @view = ActiongraphTreeView.new

          when :actionlist
            @view = ActionlistTreeView.new

          else

            sid = current_item

            storage = Yast::Storage::StorageManager.instance
            staging = storage.staging

            device = staging.find_device(sid)

            if Storage.disk?(device)
              @view = DiskTreeView.new(Storage.to_disk(device))
            elsif Storage.md?(device)
              @view = MdTreeView.new(Storage.to_md(device))
            elsif Storage.partition?(device)
              @view = PartitionTreeView.new(Storage.to_partition(device))
            end

          end

          @view.update

        else
          log.warn "Unexpected input #{input}"
        end

      end
    end

    def do_commit
      storage = Yast::Storage::StorageManager.instance
      actiongraph = storage.calculate_actiongraph

      if actiongraph.empty?
        Yast::Popup::Error("Nothing to commit.")
        return false
      end
      if !Yast::Popup::YesNo("Really commit?")
        return false
      end

      storage.calculate_actiongraph
      storage.commit

      return true
    end
  end
end
