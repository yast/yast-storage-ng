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

require "yast"
require "storage/proposal"
require "storage/yaml_writer"

output_file = ARGV[0] || "proposed_devicegraph.yml"

if Process::UID.eid != 0
  STDERR.puts("This requires root permissions, otherwise hardware probing will fail.")
  STDERR.puts("Start this with sudo")
end

settings = Yast::Storage::Proposal::Settings.new
proposal = Yast::Storage::Proposal.new(settings: settings)
proposal.propose
Yast::Storage::YamlWriter.write(proposal.devices, output_file)
