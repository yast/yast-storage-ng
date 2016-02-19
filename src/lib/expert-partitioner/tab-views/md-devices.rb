
require "yast"
require "storage"
require "storage/storage-manager"
require "storage/extensions"
require "expert-partitioner/tab-views/view"
require "expert-partitioner/popups"

Yast.import "UI"
Yast.import "Popup"

include Yast::I18n
include Yast::Logger


module ExpertPartitioner


  class MdDevicesTabView < TabView

    FIELDS = [ :sid, :icon, :name, :size, :spare ]


    def initialize(md)
      @md = md
    end


    def create
      VBox(
        Table(Id(:table), Opt(:keepSorting), Storage::Device.table_header(FIELDS), items)
      )
    end


    private


    def items

      ret = []

      blk_devices = @md.devices()

      blk_devices.each do |blk_device|
        blk_device = Storage::downcast(blk_device)
        ret << blk_device.table_row(FIELDS)
      end

      return ret

    end


  end

end
