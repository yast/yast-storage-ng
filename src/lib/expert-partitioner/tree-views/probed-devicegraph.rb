
require "yast"
require "storage"
require "storage/storage-manager"
require "expert-partitioner/tree-views/view"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class ProbedDevicegraphTreeView < TreeView

    def create

      storage = Yast::Storage::StorageManager.instance

      filename = "#{Yast::Directory.tmpdir}/devicegraph-probed.gv"

      probed = storage.probed()
      probed.write_graphviz(filename)

      VBox(
        Left(Heading(_("Device Graph (probed)"))),
        Yast::Term.new(:Graph, Id(:graph), Opt(:notify, :notifyContextMenu), filename, "dot"),
      )

    end

  end

end
