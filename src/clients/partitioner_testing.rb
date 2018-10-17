# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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
# TODO: just temporary client for testing partitioner with different hardware setup
# call with `yast2 partitioner_testing <path_to_yaml>`

require "yast"
require "y2partitioner/clients/main"
require "y2storage"

# Comment next line and run the file with root privileges to test system lock
Y2Storage::StorageManager.create_test_instance

arg = Yast::WFM.Args.first
case arg
when /.ya?ml$/
  Y2Storage::StorageManager.instance(mode: :rw).probe_from_yaml(arg)
when /.xml$/
  # note: support only xml device graph, not xml output of probing commands
  Y2Storage::StorageManager.instance(mode: :rw).probe_from_xml(arg)
else
  raise "Invalid testing parameter #{arg}, expecting foo.yml or foo.xml."
end

# Run this like this:
# Y2DIR=../yast-yast2/library/cwm/src/:src \
#   ruby.ruby2.5 -ryast \
#   -e 'load "src/lib/y2storage/storage_class_wrapper.rb";
#       Yast.ui_component="qt";
#       Yast.import "Arch";
#       Yast::Arch.s390;
#       load "/usr/lib/YaST2/bin/y2start"' \
#   -- \
#   partitioner_testing -a test/data/devicegraphs/nested_md_raids.yml qt
# ^ explanation:
# The things done before 'load y2start' perform initializations
# (storage, UI, probing) that I want to keep out of the profile data

Yast.import "UI"
# Monkey Patch! This is a crude but effective UI Macro Player
events = [
  { "ID" => :yes }, # we are experts
  { "ID" => "Y2Partitioner::Widgets::OverviewTree" }, # click the tree
  # where did we click? see `queries` below
  { "ID" => "Y2Partitioner::Widgets::OverviewTree" }, # click the tree again
  { "ID" => :abort } # bye
]
old_wfe = Yast::UI.singleton_method(:WaitForEvent)
Yast::UI.define_singleton_method(:WaitForEvent) do
  e = events.shift
  e ||= old_wfe.call
  Yast.y2milestone "WFE: #{e}"
  e
end

Yast::UI.define_singleton_method(:UserInput) do
  Yast.y2milestone "UI"
  Yast::UI.WaitForEvent["ID"]
end

queries = [
  ["table:device:42"],
  ["table:device:42"],
  "Y2Partitioner::Widgets::Pages::MdRaids",
  ["table:device:42"],
  ["table:device:42"],
  "Y2Partitioner::Widgets::Pages::System"
]
old_qw = Yast::UI.singleton_method(:QueryWidget)
Yast::UI.define_singleton_method(:QueryWidget) do |*args|
  e = queries.shift
  e ||= old_qw.call(*args)
  Yast.y2milestone "QW(#{args}): #{e}"
  e
end

# Run the rbspy profiler on this.
# It should be possible to run it from the outside but something in YaST
# initialization confuses it (cannot find the stack...) so this works better
system "rbspy record --pid #{$$} --file rbspy.flamegraph --raw-file rbspy.raw.gz --rate 250 &"
sleep 1

Y2Partitioner::Clients::Main.new.run(allow_commit: false)
