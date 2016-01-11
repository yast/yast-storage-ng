
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

      # TODO this kind of runtime polymorphism does not work right away
      # without the code block below the icon in the table is wrong
      # http://nickdarnell.com/swig-casting-revisited/
      # https://github.com/swig/swig/blob/master/Lib/typemaps/factory.swg

      blk_devices = blk_devices.to_a.map do |blk_device|
        if ::Storage::partition?(blk_device)
          ::Storage::to_partition(blk_device)
        elsif ::Storage::disk?(blk_device)
          ::Storage::to_disk(blk_device)
        elsif ::Storage::md?(blk_device)
          ::Storage::to_md(blk_device)
        else
          blk_device
        end
      end

      blk_devices.each do |blk_device|
        ret << blk_device.table_row(FIELDS)
      end

      return ret

    end


  end

end
