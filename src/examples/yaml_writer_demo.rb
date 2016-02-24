#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require "storage/fake_probing.rb"
require "storage/fake_device_factory.rb"
require "storage/yaml_writer.rb"

input_file  = ARGV[0] || "fake-devicegraphs.yml"
output_file = ARGV[1] || "/dev/stdout"

fake_probing = Yast::Storage::FakeProbing.new
devicegraph = fake_probing.devicegraph
factory = Yast::Storage::FakeDeviceFactory.new(devicegraph)
factory.load_yaml_file(input_file)

yaml_writer = Yast::Storage::YamlWriter.new
yaml_writer.write(devicegraph, output_file)


