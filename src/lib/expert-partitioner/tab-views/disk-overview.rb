
require "yast"
require "storage"
require "expert-partitioner/tab-views/view"
require "expert-partitioner/popups"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger


module ExpertPartitioner


  class DiskOverviewTabView < TabView

    def initialize(disk)
      @disk = disk
    end


    def create

      tmp = [ "Name: #{@disk.name}",
              "Size: #{::Storage::byte_to_humanstring(1024 * @disk.size_k, false, 2, false)}" ]

      tmp << "Device Path: #{@disk.udev_path}"

      @disk.udev_ids.each_with_index do |udev_id, i|
        tmp << "Device ID #{i + 1}: #{udev_id}"
      end

      contents = Yast::HTML.List(tmp)

      return RichText(Id(:text), Opt(:hstretch, :vstretch), contents)

    end

  end

end
