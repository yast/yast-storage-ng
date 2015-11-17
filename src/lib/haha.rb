
require "yast"
require "yastx"
require "storage"


class Haha


  class MyLogger < ::Storage::Logger

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

    @environment = Storage::Environment.new(true)

    @storage = Storage::Storage.new(@environment)

  end


  def storage
    return @storage
  end


end


if $PROGRAM_NAME == __FILE__

  haha = Haha.new

  probed = haha.storage.probed()
  print probed

end
