
require "yast"
require "yastx"
require "storage"


module ExpertPartitioner

  @haha = nil

  def init()
    @haha = Haha.new()
  end

  def get_haha()
    return @haha
  end

  module_function :init, :get_haha


  class Haha

    class MyLogger < Storage::Logger

      def initialize()
        super()
      end

      def write(level, component, filename, line, function, content)
        Yast::y2_logger(level, component, filename, line, function, content)
      end

    end


    def initialize

      @my_logger = MyLogger.new()
      Storage::logger = @my_logger

      case "A"
      when "A"                  # probe
        @environment = Storage::Environment.new(true)

      when "B"                  # probe and write probed data to disk
        @environment = Storage::Environment.new(true, Storage::ProbeMode_STANDARD_WRITE_DEVICEGRAPH,
                                                Storage::TargetMode_DIRECT)
      when "C"                 # instead of probing read probed data from disk
        @environment = Storage::Environment.new(true, Storage::ProbeMode_READ_DEVICEGRAPH,
                                                Storage::TargetMode_DIRECT)
      end

      @environment.devicegraph_filename = "./devicegraph.xml"
      @environment.arch_filename = "./arch.xml"

      @storage = Storage::Storage.new(@environment)

    end


    def storage
      return @storage
    end

  end

end


if $PROGRAM_NAME == __FILE__

  haha = Haha.new

  probed = haha.storage.probed()
  print probed

end
