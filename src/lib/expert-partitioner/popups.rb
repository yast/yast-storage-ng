
require "yast"
require "storage"
require "storage/storage-manager"

Yast.import "UI"
Yast.import "Label"
Yast.import "Popup"


module ExpertPartitioner

  class RemoveDescendantsPopup

    def initialize(device)
      textdomain "storage"
      @device = device
    end

    def run

      if @device.num_children == 0
        return true
      end

      log.info "removing all descendants"
      descendants = @device.descendants(false)

      tmp = descendants.to_a.map { |descendant| descendant.to_s }.join("\n")
      if !Yast::Popup::YesNo("Will delete:\n#{tmp}")
        return false
      end

      @device.remove_descendants()

      return true

    end

  end

end
