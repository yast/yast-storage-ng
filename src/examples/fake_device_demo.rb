#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require "storage/fake_probing.rb"
require "storage/fake_device_factory.rb"

FILENAME = "fake-devicegraphs"

fake_probing = Yast::Storage::FakeProbing.new
devicegraph = fake_probing.devicegraph
factory = Yast::Storage::FakeDeviceFactory.new(devicegraph)
factory.load_yaml_file("#{FILENAME}.yml")

fake_probing.to_probed
puts("Disks:")
probed = Yast::Storage::StorageManager.instance.probed
fake_probing.dump_disks(probed)

# Write to graphviz format, convert to .png and display
probed.write_graphviz("#{FILENAME}.gv")
system("dot -Tpng <#{FILENAME}.gv >#{FILENAME}.png")
system("display #{FILENAME}.png")

# Clean up
File.delete("#{FILENAME}.gv")
File.delete("#{FILENAME}.png")
