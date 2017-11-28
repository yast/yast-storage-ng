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

describe Y2Storage::Device do
  before do
    fake_scenario("complex-lvm-encrypt")
  end

  describe "#ancestors" do
    subject(:device) { Y2Storage::LvmLv.find_by_name(fake_devicegraph, "/dev/vg0/lv1").blk_filesystem }

    it "does not include the device itself" do
      expect(device.ancestors.map(&:sid)).to_not include device.sid
    end

    it "includes all the ancestors" do
      expect(device.ancestors.size).to eq 10
    end

    it "returns objects of the right classes" do
      all = device.ancestors
      expect(all.select { |i| i.is?(:lvm_lv) }.size).to eq 1
      expect(all.select { |i| i.is?(:lvm_vg) }.size).to eq 1
      expect(all.select { |i| i.is?(:lvm_pv) }.size).to eq 2
      expect(all.select { |i| i.is?(:encryption) }.size).to eq 2
      expect(all.select { |i| i.is?(:partition) }.size).to eq 1
      expect(all.select { |i| i.is?(:disk) }.size).to eq 2
      expect(all.select { |i| i.is?(:partition_table) }.size).to eq 1
    end
  end

  describe "#descendants" do
    subject(:device) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }

    it "does not include the device itself" do
      expect(device.descendants.map(&:sid)).to_not include device.sid
    end

    it "includes all the descendants" do
      expect(device.descendants.size).to eq 9
    end

    it "returns objects of the right classes" do
      all = device.descendants
      expect(all.select { |i| i.is?(:partition_table) }.size).to eq 1
      expect(all.select { |i| i.is?(:partition) }.size).to eq 4
      expect(all.select { |i| i.is?(:filesystem) }.size).to eq 3
      expect(all.select { |i| i.is?(:encryption) }.size).to eq 1
    end
  end

  describe "#siblings" do
    subject(:device) { Y2Storage::Partition.find_by_name(fake_devicegraph, "/dev/sda1") }

    it "does not include the device itself" do
      expect(device.siblings.map(&:sid)).to_not include device.sid
    end

    it "includes all the siblings" do
      expect(device.siblings.map(&:name)).to contain_exactly("/dev/sda2", "/dev/sda3", "/dev/sda4")
    end

    it "returns objects of the right classes" do
      expect(device.siblings).to all(be_a(Y2Storage::Partition))
    end
  end

  describe "#can_resize?" do
    subject(:device) { Y2Storage::Partition.find_by_name(fake_devicegraph, "/dev/sda1") }
    let(:resize_info) { double(Y2Storage::ResizeInfo, resize_ok?: resize_ok) }
 
    before { allow(device).to receive(:detect_resize_info).and_return resize_info }
 
    context "if libstorage-nd reports that resizing is possible" do
      let(:resize_ok) { true }
 
      it "returns true" do
        expect(device.can_resize?).to eq true
      end
    end
 
    context "if libstorage-ng reports that resizing is not possible" do
      let(:resize_ok) { false }
 
      it "returns false" do
        expect(device.can_resize?).to eq false
      end
    end
  end
end
