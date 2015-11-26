
require "yast"
require "storage"
require "storage/storage-manager"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class StagingDevicegraphView

    def create

      storage = Yast::Storage::StorageManager.instance

      filename = "#{Yast::Directory.tmpdir}/devicegraph-staging.gv"

      staging = storage.staging()
      staging.write_graphviz(filename)

      return VBox(
               Heading(_("Device Graph (staging)")),
               Yast::Term.new(:Graph, Id(:graph), Opt(:notify, :notifyContextMenu), filename, "dot"),
             )

    end

  end

end
