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

# usage
#
# either
#
#   boot_req_checker_demo DEVICEGRAPH_AS_YAML_FILE
#     - use supplied device graph
#
# or
#
#   boot_req_checker_demo
#     - probe current config
#


require "yast"	# changes $LOAD_PATH

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "storage/boot_requirements_checker.rb"
require "storage/proposal/settings.rb"
require "storage/disk_analyzer"
require "pp"


if ARGV[0]
  sm = Yast::Storage::StorageManager.fake_from_yaml(ARGV[0])
else
  sm = Yast::Storage::StorageManager.instance
end

devicegraph = sm.probed

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
