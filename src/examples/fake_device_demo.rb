#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require "storage/fake_probing.rb"
require "storage/fake_device_factory.rb"

fake_probing = Yast::Storage::FakeProbing.new
devicegraph = fake_probing.devicegraph
factory = Yast::Storage::FakeDeviceFactory.new(devicegraph)
factory.load_yaml_file("fake-devicegraphs.yml")

fake_probing.to_probed
puts("Disks:")
fake_probing.dump_disks(Yast::Storage::StorageManager.instance.probed)
