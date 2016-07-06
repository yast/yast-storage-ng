# encoding: utf-8

# Copyright (c) [2015-2016] SUSE LLC
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
require "expert_partitioner/tree_views/view"
require "expert_partitioner/icons"

Yast.import "UI"
Yast.import "HTML"

include Yast::I18n

module ExpertPartitioner
  class BcacheCsetTreeView < TreeView
    def initialize(bcache_cset)
      @bcache_cset = bcache_cset
    end

    def create
      tmp = ["UUID: #{@bcache_cset.uuid}"]

      contents = Yast::HTML.List(tmp)

      VBox(
        Left(IconAndHeading(_("Bcache Cset: %s") % @bcache_cset.uuid, Icons::BCACHE_CSET)),
        RichText(Id(:text), Opt(:hstretch, :vstretch), contents)
      )
    end
  end
end
