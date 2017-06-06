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
#   boot_req_checker_demo.rb DEVICES ROOT_DEVICE
#
#   DEVICES:     either a YAML file or the empty string (indicating probing the running system)
#   ROOT_DEVICE: device to check; if unset, find a suitable device
#

require "yast"	# changes $LOAD_PATH

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "y2storage"
require "pp"

begin
  Y2Storage::StorageManager.fake_from_yaml(ARGV[0]) unless ARGV[0].nil? || ARGV[0].empty?
  sm = Y2Storage::StorageManager.instance

  devicegraph = sm.y2storage_probed
  Y2Storage::YamlWriter.write(devicegraph, $stdout)
rescue => x
  puts "exception: #{x}"
  pp x.backtrace
end

root_device = Y2Storage::Planned::LvmLv.new("/", Y2Storage::Filesystems::Type::BTRFS)
boot_device = ARGV[1]

puts "\n---  needed  ---"
checker = Y2Storage::BootRequirementsChecker.new(
  devicegraph, planned_devices: [root_device], boot_disk_name: boot_device
)

begin
  needed = checker.needed_partitions
  pp(needed)
rescue Y2Storage::BootRequirementsChecker::Error => x
  puts "exception: #{x}"
end
