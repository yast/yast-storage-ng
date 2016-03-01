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
require "expert-partitioner/tree-views/view"

Yast.import "UI"

include Yast::I18n

module ExpertPartitioner
  class ActionlistTreeView < TreeView
    def create
      storage = Yast::Storage::StorageManager.instance

      # storage.probed().save("./devicegraph-probed.xml")
      # storage.staging().save("./devicegraph-staging.xml")

      actiongraph = storage.calculate_actiongraph
      steps = actiongraph.commit_actions_as_strings

      VBox(
        Left(Heading(_("Installation Steps"))),
        RichText(Yast::HTML.List(steps.to_a))
      )
    end
  end
end
