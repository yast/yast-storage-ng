
require "yast"
require "storage"
require "storage/storage-manager"
require "expert-partitioner/tree-views/view"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class StagingDevicegraphTreeView < TreeView

    def create

      storage = Yast::Storage::StorageManager.instance

      filename = "#{Yast::Directory.tmpdir}/devicegraph-staging.gv"

      staging = storage.staging()
      staging.write_graphviz(filename)

      VBox(
        Left(Heading(_("Device Graph (staging)"))),
        Yast::Term.new(:Graph, Id(:graph), Opt(:notify, :notifyContextMenu), filename, "dot"),
      )

    end

  end

end
