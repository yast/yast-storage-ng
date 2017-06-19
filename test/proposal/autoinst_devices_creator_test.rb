#!/usr/bin/env rspec
#
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

require_relative "../spec_helper"
require "y2storage/proposal/autoinst_devices_creator"
require "y2storage/planned/partition"

describe Y2Storage::Proposal::AutoinstDevicesCreator do
  let(:filesystem_type) { Y2Storage::Filesystems::Type::EXT4 }
  let(:new_part) { Y2Storage::Planned::Partition.new("/home", Y2Storage::Filesystems::Type::EXT4) }
  let(:scenario) { "windows-linux-free-pc" }
  let(:reusable_part) do
    Y2Storage::Planned::Partition.new("/", filesystem_type).tap do |part|
      part.reuse = "/dev/sda3"
    end
  end

  before { fake_scenario(scenario) }

  subject(:creator) do
    described_class.new(Y2Storage::StorageManager.instance.y2storage_probed)
  end

  describe "#populated_devicegraph" do
    it "creates new partitions" do
      devicegraph = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      _win, _swap, _root, home = devicegraph.partitions
      expect(home).to have_attributes(
        filesystem_type:       filesystem_type,
        filesystem_mountpoint: "/home"
      )
    end

    it "reuses partitions" do
      devicegraph = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      root = devicegraph.partitions.find { |p| p.filesystem_mountpoint == "/" }
      expect(root).to have_attributes(
        filesystem_label: "root"
      )
    end

    it "ignores other disks" do
      devicegraph = creator.populated_devicegraph([new_part, reusable_part], "/dev/sda")
      sdb = devicegraph.disks.find { |d| d.name == "/dev/sdb" }
      expect(sdb.partitions).to be_empty
    end
  end
end
