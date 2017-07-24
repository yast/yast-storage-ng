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

  describe "#detect_resize_info" do
    let(:probed) { double(Y2Storage::Devicegraph) }
    let(:probed_partition) { double(Y2Storage::Partition, storage_detect_resize_info: resize_info) }
    let(:resize_info) { double(Y2Storage::ResizeInfo) }
    let(:wrapped_partition) { double(Storage::Partition, exists_in_probed?: in_probed, sid: 444) }

    subject(:staging_partition) { Y2Storage::Partition.new(wrapped_partition) }

    before do
      allow(Storage).to receive(:to_partition) do |object|
        object
      end
      allow(Y2Storage::StorageManager.instance).to receive(:probed).and_return probed
    end

    context "if the device does not exist in probed" do
      let(:in_probed) { false }

      it "returns nil" do
        expect(staging_partition.detect_resize_info).to be_nil
      end
    end

    context "if the device exists in probed" do
      let(:in_probed) { true }

      it "returns the resize info from the equivalent partition in probed" do
        expect(probed).to receive(:find_device).with(444).and_return probed_partition
        expect(staging_partition.detect_resize_info).to eq resize_info
      end
    end
  end
end
