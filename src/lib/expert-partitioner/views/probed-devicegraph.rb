
require "yast"
require "storage"
require "storage/storage-manager"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class ProbedDevicegraphView

    def create

      storage = Yast::Storage::StorageManager.instance

      filename = "#{Yast::Directory.tmpdir}/devicegraph-probed.gv"

      probed = storage.probed()
      probed.write_graphviz(filename)

      return VBox(
               Heading(_("Device Graph (probed)")),
               Yast::Term.new(:Graph, Id(:graph), Opt(:notify, :notifyContextMenu), filename, "dot"),
             )

    end

  end

end
