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
require "y2storage"

opts = GetoptLong.new(
  ["--help", GetoptLong::NO_ARGUMENT],
  ["--probe", GetoptLong::NO_ARGUMENT],
  ["--propose", GetoptLong::NO_ARGUMENT],
  ["--lvm", GetoptLong::NO_ARGUMENT],
  ["--encryption", GetoptLong::NO_ARGUMENT],
  ["--gfx", GetoptLong::NO_ARGUMENT],
  ["--yaml", GetoptLong::REQUIRED_ARGUMENT],
  ["--xml", GetoptLong::REQUIRED_ARGUMENT],
  ["--del-partitions", GetoptLong::REQUIRED_ARGUMENT]
)

usage = <<XXX
device_demo.rb [OPTIONS]

Probe device tree or read device tree from YAML file, optionally propose a
new device tree, and then either show the new tree as graphics or write the
new tree as YAML file to stdout.

If no option is given, probe device tree.

Options:
  --xml XML_FILE                  Read device tree from XML_FILE
  --yaml YAML_FILE                Read device tree from YAML_FILE
  --probe                         Probe device tree (default if neither --xml nor --yaml is used).
  --lvm                           Create LVM-based proposal.
  --encryption                    Encrypt file systems.
  --propose                       Propose new device tree.
  --del-partitions SID1,SID2,...  Delete partitions with given storage ids from device tree.
  --gfx                           Show device tree as graphics.
  --help                          Write this text.
XXX

yaml_input = nil
xml_input = nil
opt_propose = false
opt_gfx = false
opt_lvm = false
opt_encryption = nil
opt_del_parts = nil

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
    when "--lvm"
      opt_lvm = true
    when "--encryption"
      opt_encryption = "*****"
    when "--gfx"
      opt_gfx = true
    when "--yaml"
      yaml_input = arg
    when "--xml"
      xml_input = arg
    when "--del-partitions"
      opt_del_parts = arg.split(",").map(&:to_i)
    end
  end
rescue
  abort usage
end

abort usage if !ARGV.empty?

if !Process.euid.zero?
  STDERR.puts "You need to run this script as 'root'."
  exit 1
end

if yaml_input.nil? && xml_input.nil?
  Y2Storage::StorageManager.instance.probe
elsif xml_input.nil?
  Y2Storage::StorageManager.instance.probe_from_yaml(yaml_input)
else
  Y2Storage::StorageManager.instance.probe_from_xml(xml_input)
end
devicegraph = Y2Storage::StorageManager.instance.probed

if opt_propose
  # propose new device graph
  settings = Y2Storage::ProposalSettings.new
  settings.use_lvm = opt_lvm
  settings.encryption_password = opt_encryption
  proposal = Y2Storage::GuidedProposal.new(settings: settings)
  proposal.propose
  devicegraph = proposal.devices
end

if opt_del_parts
  pk = Y2Storage::Proposal::PartitionKiller.new(devicegraph)
  opt_del_parts.each { |sid| pk.delete_by_sid(sid) }
end

if opt_gfx
  # write to graphviz format, convert to .png and display
  begin
    FILENAME = "fake-devicegraphs"
    devicegraph.write_graphviz(
      "#{FILENAME}.gv",
      Storage::GraphvizFlags_CLASSNAME | Storage::GraphvizFlags_DISPLAYNAME |
      Storage::GraphvizFlags_SID | Storage::GraphvizFlags_SIZE |
      Storage::GraphvizFlags_IN_ETC | Storage::GraphvizFlags_ACTIVE
    )
    system("dot -Tpng -Nfontsize=11 <#{FILENAME}.gv >#{FILENAME}.png")
    system("display #{FILENAME}.png")
  ensure
    # clean up
    File.delete("#{FILENAME}.gv")
    File.delete("#{FILENAME}.png")
  end
else
  # write as YAML file
  Y2Storage::YamlWriter.write(devicegraph, $stdout)
end
