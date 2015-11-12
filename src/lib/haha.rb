
require "yast"
require "storage"

class Haha

  def initialize
    environment = Storage::Environment.new(true)
    @storage = Storage::Storage.new(environment)

    probed = storage.probed()
    print probed
   
  end

  def storage
    return @storage
  end

end
