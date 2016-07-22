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

require "getoptlong"
require "yast"	# Changes $LOAD_PATH!
$LOAD_PATH.unshift(File.expand_path("../../lib", __FILE__))
require "storage/storage_manager"
require "storage/proposal"
require "storage/yaml_writer"

opts = GetoptLong.new(
  ["--help", GetoptLong::NO_ARGUMENT],
  ["--probe", GetoptLong::NO_ARGUMENT],
  ["--propose", GetoptLong::NO_ARGUMENT],
  ["--gfx", GetoptLong::NO_ARGUMENT],
  ["--yaml", GetoptLong::REQUIRED_ARGUMENT]
)

usage = <<XXX
device_demo.rb [OPTIONS]

Probe device tree or read device tree from YAML file, optionally propose a
new device tree, and then either show the new tree as graphics or write the
new tree as YAML file to stdout.

If no option is given, read from fake-devicegraphs.yml.

Options:
  --yaml YAML_FILE      Read device tree from YAML_FILE
  --probe               Probe device tree.
  --propose             Propose new device tree.
  --gfx                 Show device tree as graphics.
  --help                Write this text.
XXX

yaml_input = "fake-devicegraphs.yml"
opt_propose = false
opt_gfx = false

begin
  opts.each do |opt, arg|
    case opt
    when "--help"
      puts usage
      exit 0
    when "--probe"
      yaml_input = nil
    when "--propose"
      opt_propose = true
    when "--gfx"
      opt_gfx = true
    when "--yaml"
      yaml_input = arg
    end
  end
rescue
  abort usage
end

abort usage if !ARGV.empty?

if yaml_input.nil?
  if Process::UID.eid != 0 && !File.readable?("/dev/loop-control")
    STDERR.puts("This requires root permissions, otherwise hardware probing might fail.")
    STDERR.puts("Start this with sudo.")
  end
  devicegraph = Yast::Storage::StorageManager.instance.probed
else
  devicegraph = Yast::Storage::StorageManager.fake_from_yaml(yaml_input).probed
end

if opt_propose
  # propose new device graph
  settings = Yast::Storage::Proposal::Settings.new
  proposal = Yast::Storage::Proposal.new(settings: settings)
  proposal.propose
  devicegraph = proposal.devices
end

if opt_gfx
  # write to graphviz format, convert to .png and display
  begin
    FILENAME = "fake-devicegraphs"
    devicegraph.write_graphviz("#{FILENAME}.gv")
    system("dot -Tpng <#{FILENAME}.gv >#{FILENAME}.png")
    system("display #{FILENAME}.png")
  ensure
    # clean up
    File.delete("#{FILENAME}.gv")
    File.delete("#{FILENAME}.png")
  end
else
  # write as YAML file
  Yast::Storage::YamlWriter.write(devicegraph, $stdout)
end
