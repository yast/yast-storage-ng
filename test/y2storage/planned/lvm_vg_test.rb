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
require "y2storage/planned"

describe Y2Storage::Planned::LvmVg do
  subject(:lvm_vg) { described_class.new(volume_group_name: name) }

  let(:lv_root) { Y2Storage::Planned::LvmLv.new("/", :ext4) }
  let(:name) { "system" }
  let(:vg0) { fake_devicegraph.lvm_vgs.find { |v| v.vg_name == "vg0" } }

  before do
    fake_scenario("lvm-two-vgs")
  end

  describe ".from_real_vg" do
    subject(:planned_vg) { described_class.from_real_vg(vg0) }

    it "builds a new instance" do
      expect(planned_vg.volume_group_name).to eq(vg0.vg_name)
    end

    it "sets extent_size" do
      expect(planned_vg.extent_size).to eq(vg0.extent_size)
    end

    it "sets total_size" do
      expect(planned_vg.total_size).to eq(vg0.total_size)
    end

    it "sets reuse" do
      expect(planned_vg.reuse_name).to eq(vg0.vg_name)
    end

    it "sets pvs" do
      expect(planned_vg.pvs).to eq(["/dev/sda7"])
    end

    it "sets lvs" do
      expect(planned_vg.lvs.map(&:logical_volume_name)).to contain_exactly("lv1", "lv2")
    end
  end

  describe "#volume_group_name" do
    it "returns the volume group name" do
      expect(lvm_vg.volume_group_name).to eq(name)
    end
  end

  describe "#reuse!" do
    before do
      lvm_vg.reuse_name = name
    end

    it "finds the device to reuse" do
      expect(Y2Storage::LvmVg).to receive(:find_by_vg_name).with(fake_devicegraph, name)
      lvm_vg.reuse!(fake_devicegraph)
    end
  end
end
