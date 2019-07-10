#!/usr/bin/env rspec
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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::LvmVg do
  using Y2Storage::Refinements::SizeCasts

  before do
    fake_scenario("complex-lvm-encrypt")
  end

  subject(:vg) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, vg_name) }

  let(:vg_name) { "vg0" }

  describe "#name" do
    it "returns string starting with /dev and containing vg_name" do
      subject = Y2Storage::StorageManager.instance.staging.lvm_vgs.first
      expect(subject.name).to start_with("/dev")
      expect(subject.name).to include(subject.vg_name)
    end
  end

  describe ".sorted_by_name" do
    it "returns all the volume groups sorted by name" do
      devices = Y2Storage::LvmVg.sorted_by_name(fake_devicegraph)
      expect(devices.map(&:basename)).to eq ["vg0", "vg1"]
    end
  end

  describe "lvm_lvs" do
    before do
      create_thin_provisioning(vg)
    end

    it "includes all normal volumes" do
      expect(vg.lvm_lvs.map(&:lv_name)).to include("lv1", "lv2")
    end

    it "includes all thin pools" do
      expect(vg.lvm_lvs.map(&:lv_name)).to include("pool1", "pool2")
    end

    it "does not include thin volumes" do
      expect(vg.lvm_lvs.map(&:lv_name)).to_not include("thin1", "thin2", "thin3")
    end
  end

  describe "all_lvm_lvs" do
    before do
      create_thin_provisioning(vg)
    end

    it "includes all normal volumes" do
      expect(vg.all_lvm_lvs.map(&:lv_name)).to include("lv1", "lv2")
    end

    it "includes all thin pools" do
      expect(vg.all_lvm_lvs.map(&:lv_name)).to include("pool1", "pool2")
    end

    it "includes all thin volumes" do
      expect(vg.all_lvm_lvs.map(&:lv_name)).to include("thin1", "thin2", "thin3")
    end
  end

  describe "thin_pool_lvm_lvs" do
    before do
      create_thin_provisioning(vg)
    end

    it "includes all thin pools" do
      expect(vg.thin_pool_lvm_lvs.map(&:lv_name)).to include("pool1", "pool2")
    end

    it "does not include normal volumes" do
      expect(vg.thin_pool_lvm_lvs.map(&:lv_name)).to_not include("lv1", "lv2")
    end

    it "does not include thin volumes" do
      expect(vg.thin_pool_lvm_lvs.map(&:lv_name)).to_not include("thin1", "thin2", "thin3")
    end
  end

  describe "thin_lvm_lvs" do
    before do
      create_thin_provisioning(vg)
    end

    it "includes all thin volumes" do
      expect(vg.thin_lvm_lvs.map(&:lv_name)).to include("thin1", "thin2", "thin3")
    end

    it "does not include normal volumes" do
      expect(vg.thin_lvm_lvs.map(&:lv_name)).to_not include("lv1", "lv2")
    end

    it "does not include thin pools" do
      expect(vg.thin_lvm_lvs.map(&:lv_name)).to_not include("pool1", "pool2")
    end
  end
end
