
require "yast"
require "storage"
require "storage/storage-manager"
require "expert-partitioner/views/view"

Yast.import "UI"

include Yast::I18n


module ExpertPartitioner

  class ActionlistView < View

    def create

      storage = Yast::Storage::StorageManager.instance

      # storage.probed().save("./devicegraph-probed.xml")
      # storage.staging().save("./devicegraph-staging.xml")

      actiongraph = storage.calculate_actiongraph()
      steps = actiongraph.commit_actions_as_strings()

      return VBox(
               Heading(_("Installation Steps")),
               RichText(Yast::HTML.List(steps.to_a)),
             )

    end

  end

end
