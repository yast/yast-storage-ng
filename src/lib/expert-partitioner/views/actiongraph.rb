
require "yast"
require "storage"
require "storage/storage-manager"
require "expert-partitioner/views/view"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class ActiongraphView < View

    def create

      storage = Yast::Storage::StorageManager.instance

      filename = "#{Yast::Directory.tmpdir}/actiongraph.gv"

      actiongraph = storage.calculate_actiongraph()
      actiongraph.write_graphviz(filename)

      return VBox(
               Heading(_("Action Graph")),
               Yast::Term.new(:Graph, Id(:graph), Opt(:notify, :notifyContextMenu), filename, "dot"),
             )

    end

  end

end
