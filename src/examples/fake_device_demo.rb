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

$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))

require "storage/storage_manager.rb"

FILENAME = "fake-devicegraphs"
input_file  = ARGV[0] || "fake-devicegraphs.yml"

probed = Yast::Storage::StorageManager.fake_from_yaml(input_file).probed

# Write to graphviz format, convert to .png and display
probed.write_graphviz("#{FILENAME}.gv")
system("dot -Tpng <#{FILENAME}.gv >#{FILENAME}.png")
system("display #{FILENAME}.png")

# Clean up
File.delete("#{FILENAME}.gv")
File.delete("#{FILENAME}.png")
