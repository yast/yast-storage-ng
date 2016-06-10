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
#   boot_req_checker_demo DEVICES ROOT_DEVICE
#
#   DEVICES:     either a YAML file or the empty string (indicating probing the running system)
#   ROOT_DEVICE: device to check; if unset, find a suitable device
#

require "yast"	# changes $LOAD_PATH

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "storage/boot_requirements_checker.rb"
require "storage/proposal/settings.rb"
require "storage/disk_analyzer"
require "storage/patches"
require "pp"

begin

Yast::Storage::StorageManager.fake_from_yaml(ARGV[0]) unless ARGV[0].nil? || ARGV[0].empty?
sm = Yast::Storage::StorageManager.instance

devicegraph = sm.probed
puts(devicegraph)

rescue => x
  puts "exception: #{x}"
  pp x.backtrace
end



puts "\n---  disk_analyzer  ---"
disk_analyzer = Yast::Storage::DiskAnalyzer.new
disk_analyzer.analyze(devicegraph)
pp(disk_analyzer)

puts "\n---  settings  ---"
settings = Yast::Storage::Proposal::UserSettings.new
settings.use_lvm = true
settings.root_device = ARGV[1]
pp(settings)

puts "\n---  needed  ---"
checker = Yast::Storage::BootRequirementsChecker.new(settings, disk_analyzer)
begin
  needed = checker.needed_partitions
  pp(needed)
rescue Yast::Storage::BootRequirementsChecker::Error => x
  puts "exception: #{x}"
end
