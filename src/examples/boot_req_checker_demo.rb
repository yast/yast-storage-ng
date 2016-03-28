#!/usr/bin/env ruby
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "yast"	# changes $LOAD_PATH

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "storage/fake_probing.rb"
require "storage/fake_device_factory.rb"
require "storage/boot_requirements_checker.rb"
require "storage/proposal/settings.rb"
require "storage/disk_analyzer"
require "pp"

FILENAME = "fake-devicegraphs"
input_file  = ARGV[0] || "fake-devicegraphs.yml"

fake_probing = Yast::Storage::FakeProbing.new
devicegraph = fake_probing.devicegraph
Yast::Storage::FakeDeviceFactory.load_yaml_file(devicegraph, input_file)

puts "---  disk_analyzer  ---"
disk_analyzer = Yast::Storage::DiskAnalyzer.new
disk_analyzer.analyze(devicegraph)
pp(disk_analyzer)

puts "\n---  settings  ---"
settings = Yast::Storage::Proposal::UserSettings.new
settings.use_lvm = true
pp(settings)

puts "\n---  needed  ---"
checker = Yast::Storage::BootRequirementsChecker.new(settings, disk_analyzer)
needed = checker.needed_partitions
pp(needed)

