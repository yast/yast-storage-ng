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
require "y2storage/planned"

describe Y2Storage::Planned::DevicesCollection do
  subject(:collection) { described_class.new(devices) }

  let(:partition) { planned_partition }
  let(:disk_partition) { planned_partition }
  let(:disk) { planned_disk(partitions: [disk_partition]) }
  let(:stray_blk_device) { planned_stray_blk_device }
  let(:md) { planned_md }
  let(:lv0) { planned_lv(mount_point: "/") }
  let(:lv1) { planned_lv }
  let(:vg) { planned_vg(lvs: [lv0, lv1]) }
  let(:devices) { [partition, disk, stray_blk_device, md, vg] }

  describe "#devices" do
    context "when there are no planned devices" do
      let(:devices) { [] }

      it "returns an empty array" do
        expect(subject.devices).to eq([])
      end
    end
  end

  describe "#append" do
    let(:devices) { [disk] }

    it "adds devices at the end of the collection" do
      new_collection = collection.append([md])
      expect(new_collection.devices).to eq([disk, md])
    end
  end

  describe "#append" do
    let(:devices) { [disk] }

    it "adds devices at the beginning of the collection" do
      new_collection = collection.prepend([md])
      expect(new_collection.devices).to eq([md, disk])
    end

  end

  describe "#all" do
    it "returns all planned devices" do
      expect(collection.all).to contain_exactly(
        partition, disk_partition, disk, stray_blk_device, md, lv0, lv1, vg
      )
    end
  end

  describe "#partitions" do
    it "returns planned partitions" do
      expect(collection.partitions).to eq([partition, disk_partition])
    end
  end

  describe "#disks" do
    it "returns disks" do
      expect(collection.disks).to eq([disk])
    end
  end

  describe "#stray_blk_devices" do
    it "returns disks" do
      expect(collection.stray_blk_devices).to eq([stray_blk_device])
    end
  end

  describe "#vgs" do
    it "returns volume groups" do
      expect(collection.vgs).to eq([vg])
    end
  end

  describe "#mds" do
    it "returns MD RAID devices" do
      expect(collection.mds).to eq([md])
    end
  end

  describe "#mountable_devices" do
    it "returns all devices that can be mounted" do
      expect(collection.mountable).to contain_exactly(
        partition, disk, disk_partition, stray_blk_device, lv0, lv1, md
      )
    end
  end

  describe "#each" do
    it "yields each element" do
      expect { |b| subject.each(&b) }.to yield_successive_args(*subject.all)
    end
  end
end
