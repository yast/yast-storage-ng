
require "yast"
require "storage"
require "expert-partitioner/tab-views/view"
require "expert-partitioner/popups"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger


module ExpertPartitioner


  class MdOverviewTabView < TabView

    def initialize(md)
      @md = md
    end


    def create

      tmp = [ "Name: #{@md.name}",
              "Size: #{::Storage::byte_to_humanstring(1024 * @md.size_k, false, 2, false)}" ]

      @md.udev_ids.each_with_index do |udev_id, i|
        tmp << "Device ID #{i + 1}: #{udev_id}"
      end

      tmp << "Level: #{::Storage::md_level_name(@md.md_level)}"
      tmp << "Parity: #{::Storage::md_parity_name(@md.md_parity)}"
      tmp << "Chunk Size: #{::Storage::byte_to_humanstring(1024 * @md.chunk_size_k, false, 2, false)}"

      contents = Yast::HTML.List(tmp)

      return RichText(Id(:text), Opt(:hstretch, :vstretch), contents)

    end

  end

end
