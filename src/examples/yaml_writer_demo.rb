#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require "storage/fake_probing.rb"
require "storage/fake_device_factory.rb"
require "storage/yaml_writer.rb"

input_file  = ARGV[0] || "fake-devicegraphs.yml"
output_file = ARGV[1] || "/dev/stdout"

fake_probing = Yast::Storage::FakeProbing.new
devicegraph = fake_probing.devicegraph
Yast::Storage::FakeDeviceFactory.load_yaml_file(devicegraph, input_file)
Yast::Storage::YamlWriter.write(devicegraph, output_file)
