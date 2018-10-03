#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2storage"

describe Y2Storage::Proposal::MdCreator do
  using Y2Storage::Refinements::SizeCasts

  subject(:creator) { described_class.new(fake_devicegraph) }

  before do
    fake_scenario(scenario)
  end

  let(:md_level) { Y2Storage::MdLevel::RAID0 }
  let(:btrfs) { Y2Storage::Filesystems::Type::BTRFS }
  let(:scenario) { "windows-linux-free-pc" }
  let(:planned_md0) { planned_md(name: "/dev/md0", md_level: md_level, partitions: partitions) }
  let(:devices) { ["/dev/sda1", "/dev/sda2"] }
  let(:partitions) { [] }
  let(:root) do
    planned_partition({ mount_point: "/", type: btrfs, min_size: 1.GiB, max_size: 1.GiB })
  end

  describe "#create_md" do
    it "creates a new RAID" do
      result = creator.create_md(planned_md0, devices)
      devicegraph = result.devicegraph
      expect(devicegraph.md_raids.size).to eq(1)
      new_md = devicegraph.md_raids.first
      expect(new_md.name).to eq("/dev/md0")
    end

    it "adds the given devices to the new RAID" do
      result = creator.create_md(planned_md0, devices)
      devicegraph = result.devicegraph
      new_md = devicegraph.md_raids.find { |m| m.name == "/dev/md0" }
      device_names = new_md.devices.map(&:name)
      expect(device_names.sort).to eq(devices.sort)
    end

    context "when there are planned partitions" do
      let(:partitions) { [root] }

      it "adds the partitions" do
        result = creator.create_md(planned_md0, devices)
        md = result.devicegraph.md_raids.first
        part0 = md.partitions.first
        expect(part0.mount_point.path).to eq("/")
        expect(part0.size).to eq(1.GiB)
      end
    end
  end
end
