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

require "expert_partitioner/tree_views/view"

Yast.import "UI"

include Yast::I18n

module ExpertPartitioner
  class ProbedDevicegraphTreeView < TreeView
    def create
      filename = "#{Yast::Directory.tmpdir}/devicegraph-probed.gv"

      probed = storage.probed
      probed.write_graphviz(filename, ::Storage::GraphvizFlags_TOOLTIP |
                                      ::Storage::GraphvizFlags_SID |
                                      ::Storage::GraphvizFlags_SIZE)

      VBox(
        Left(Heading(_("Device Graph (probed)"))),
        Yast::Term.new(:Graph, Id(:graph), Opt(:notify, :notifyContextMenu), filename, "dot")
      )
    end
  end
end
