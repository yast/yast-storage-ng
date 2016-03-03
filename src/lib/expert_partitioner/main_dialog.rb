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
require "ui/dialog"
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
  class MainDialog < UI::Dialog
    VIEW_CLASSES = {
      all:                 AllTreeView,
      disks:               DisksTreeView,
      mds:                 MdsTreeView,
      filesystems:         FilesystemTreeView,
      devicegraph_probed:  ProbedDevicegraphTreeView,
      devicegraph_staging: StagingDevicegraphTreeView,
      actiongraph:         ActiongraphTreeView,
      actionlist:          ActionlistTreeView
    }
    private_constant :VIEW_CLASSES

    def initialize
      super
      textdomain "storage"
      @view = AllTreeView.new
    end

    def dialog_options
      Opt(:decorated, :defaultsize)
    end

    def dialog_content
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
    end

    # Redefine the reading of user input in order to pass it first to @view
    def user_input
      input = Yast::UI.UserInput
      @view.handle(input)
      input
    end

    # Redefine the event loop because we want to just log unknown
    # actions instead of raising the corresponding exception
    def event_loop
      super
    rescue RuntimeError => error
      raise unless error.message =~ /^Unknown action/
      log.warn error.message
      event_loop
    end

    def commit_handler
      finish_dialog if do_commit
    end

    def tree_handler
      @view = new_view
      @view.update
    end

    protected

    def new_view
      current_item = Yast::UI.QueryWidget(:tree, :CurrentItem)
      view_class = VIEW_CLASSES[current_item]
      return view_class.new if view_class

      storage = Yast::Storage::StorageManager.instance
      staging = storage.staging
      device = staging.find_device(current_item)

      if Storage.disk?(device)
        DiskTreeView.new(Storage.to_disk(device))
      elsif Storage.md?(device)
        MdTreeView.new(Storage.to_md(device))
      elsif Storage.partition?(device)
        PartitionTreeView.new(Storage.to_partition(device))
      else
        @view
      end
    end

    def do_commit
      storage = Yast::Storage::StorageManager.instance
      actiongraph = storage.calculate_actiongraph

      if actiongraph.empty?
        Yast::Popup::Error("Nothing to commit.")
        return false
      end
      return false unless Yast::Popup::YesNo("Really commit?")

      storage.calculate_actiongraph
      storage.commit

      return true
    end
  end
end
