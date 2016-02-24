#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require "storage/storage_manager.rb"
require "storage/yaml_writer.rb"

if Process::UID.eid != 0
  STDERR.puts("This requires root permissions, otherwise hardware probing will fail.")
  STDERR.puts("Start this with sudo")
end

output_file = ARGV.first || "/dev/stdout" 

storage = Yast::Storage::StorageManager.start_probing
yaml_writer = Yast::Storage::YamlWriter.new
yaml_writer.write(storage.probed, output_file)


