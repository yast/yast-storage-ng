#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.expand_path('../../lib', __FILE__))

require "storage/fake_device_factory.rb"

factory = Yast::Storage::FakeDeviceFactory.new(nil)
factory.load_yaml_file("fake-devicegraphs.yml")
