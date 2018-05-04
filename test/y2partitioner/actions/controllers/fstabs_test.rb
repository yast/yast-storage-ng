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

require_relative "../../test_helper"

require "y2partitioner/actions/controllers/fstabs"

describe Y2Partitioner::Actions::Controllers::Fstabs do
  def system_graph
    Y2Partitioner::DeviceGraphs.instance.system
  end

  def current_graph
    Y2Partitioner::DeviceGraphs.instance.current
  end

  def use_device(device_name)
    device = system_graph.find_by_name(device_name)
    device.remove_descendants
    vg = Y2Storage::LvmVg.create(system_graph, "vg0")
    vg.add_lvm_pv(device)
  end

  def encrypt_and_use_device(device_name)
    device = system_graph.find_by_name(device_name)
    device.remove_descendants
    encryption = device.create_encryption("cr_device")
    vg = Y2Storage::LvmVg.create(system_graph, "vg0")
    vg.add_lvm_pv(encryption)
  end

  before do
    devicegraph_stub(scenario)

    allow(Y2Partitioner::DeviceGraphs.instance).to receive(:disk_analyzer)
      .and_return(disk_analyzer)

    subject.selected_fstab = selected_fstab
  end

  let(:disk_analyzer) { instance_double(Y2Storage::DiskAnalyzer, fstabs: fstabs) }

  let(:fstabs) { [fstab1, fstab2, fstab3] }

  let(:fstab1) { instance_double(Y2Storage::Fstab) }
  let(:fstab2) { instance_double(Y2Storage::Fstab) }
  let(:fstab3) { instance_double(Y2Storage::Fstab) }

  let(:selected_fstab) { nil }

  let(:ext3) { Y2Storage::Filesystems::Type::EXT3 }

  let(:ext4) { Y2Storage::Filesystems::Type::EXT4 }

  subject { described_class.new }

  let(:scenario) { "mixed_disks.yml" }

  describe "#fstabs" do
    it "returns the list of fstabs in the system" do
      expect(subject.fstabs).to eq(fstabs)
    end
  end

  describe "#select_prev_fstab" do
    context "when the selected fstab is the first one" do
      let(:selected_fstab) { fstab1 }

      it "does not change the selected fstab" do
        subject.select_prev_fstab
        expect(subject.selected_fstab).to eq(fstab1)
      end
    end

    context "when the selected fstab is not the first one" do
      let(:selected_fstab) { fstab3 }

      it "selects the previous fstab" do
        subject.select_prev_fstab
        expect(subject.selected_fstab).to eq(fstab2)
      end
    end
  end

  describe "#select_next_fstab" do
    context "when the selected fstab is the last one" do
      let(:selected_fstab) { fstab3 }

      it "does not change the selected fstab" do
        subject.select_next_fstab
        expect(subject.selected_fstab).to eq(fstab3)
      end
    end

    context "when the selected fstab is not the last one" do
      let(:selected_fstab) { fstab1 }

      it "selects the next fstab" do
        subject.select_next_fstab
        expect(subject.selected_fstab).to eq(fstab2)
      end
    end
  end

  describe "#selected_first_fstab?" do
    context "when the first fstab is selected" do
      let(:selected_fstab) { fstab1 }

      it "returns true" do
        expect(subject.selected_first_fstab?).to eq(true)
      end
    end

    context "when the first fstab is not selected" do
      let(:selected_fstab) { fstab2 }

      it "returns false" do
        expect(subject.selected_first_fstab?).to eq(false)
      end
    end
  end

  describe "#selected_last_fstab?" do
    context "when the last fstab is selected" do
      let(:selected_fstab) { fstab3 }

      it "returns true" do
        expect(subject.selected_last_fstab?).to eq(true)
      end
    end

    context "when the last fstab is not selected" do
      let(:selected_fstab) { fstab2 }

      it "returns false" do
        expect(subject.selected_last_fstab?).to eq(false)
      end
    end
  end

  describe "#selected_fstab_errors" do
    let(:selected_fstab) { fstab1 }

    before do
      allow(fstab1).to receive(:filesystem_entries).and_return(entries)
    end

    let(:entries) { [entry1, entry2] }

    shared_examples "not importable entries error" do
      it "contains a not importable entries error" do
        expect(subject.selected_fstab_errors).to_not be_empty
        expect(subject.selected_fstab_errors).to include(/cannot be imported/)
        expect(subject.selected_fstab_errors).to include(/\/error/)
      end
    end

    context "when the device is unknown for some entry" do
      let(:entry1) { fstab_entry("/dev/sda2", "/", ext3, [], 0, 0) }
      let(:entry2) { fstab_entry("/dev/unknown", "/error", ext3, [], 0, 0) }

      include_examples "not importable entries error"
    end

    context "when the filesystem type is 'auto' for some entry" do
      let(:auto) { Y2Storage::Filesystems::Type::AUTO }

      let(:entry1) { fstab_entry("/dev/sda2", "/", ext3, [], 0, 0) }
      let(:entry2) { fstab_entry("/dev/sdb1", "/error", auto, [], 0, 0) }

      include_examples "not importable entries error"
    end

    context "when the filesystem type is unknown for some entry" do
      let(:unknown) { Y2Storage::Filesystems::Type::UNKNOWN }

      let(:entry1) { fstab_entry("/dev/sda2", "/", ext3, [], 0, 0) }
      let(:entry2) { fstab_entry("/dev/sdb1", "/error", unknown, [], 0, 0) }

      include_examples "not importable entries error"
    end

    context "when the device and the filesystem type are known for all entries" do
      let(:entry1) { fstab_entry("/dev/sda2", "/", ext3, [], 0, 0) }
      let(:entry2) { fstab_entry("/dev/sdb1", "/error", ext3, [], 0, 0) }

      context "and some device is used by other device" do
        before do
          use_device("/dev/sdb1")
        end

        include_examples "not importable entries error"
      end

      context "and some encrypted device is used by other device" do
        before do
          encrypt_and_use_device("/dev/sdb1")
        end

        include_examples "not importable entries error"
      end

      context "and neither a device nor an encrypted device is used by other device" do
        it "does not contain errors" do
          expect(subject.selected_fstab_errors).to be_empty
        end
      end
    end
  end

  describe "#import_mount_points" do
    let(:selected_fstab) { Y2Storage::Fstab.new }

    it "discards all current changes" do
      allow(selected_fstab).to receive(:entries).and_return([])

      current_graph.filesystems.first.mount_path = "/foo"

      expect(current_graph).to_not eq(system_graph)
      subject.import_mount_points
      expect(current_graph).to eq(system_graph)
    end

    before do
      allow(selected_fstab).to receive(:entries).and_return(entries)

      use_device("/dev/sdb1")
    end

    let(:entries) do
      [
        fstab_entry("/dev/sda2", "/foo", ext3, ["rw"], 0, 0),
        fstab_entry("/dev/sdb2", "/bar", ext4, ["ro"], 0, 0),
        fstab_entry("/dev/sdb1", "/", ext4, ["ro"], 0, 0),
        fstab_entry("UUID=unknown", "/foobar", "", [], 0, 0)
      ]
    end

    it "imports mount point and mount options for entries with available devices" do
      subject.import_mount_points

      sda2 = current_graph.find_by_name("/dev/sda2")
      expect(sda2.filesystem.mount_path).to eq("/foo")
      expect(sda2.filesystem.mount_options).to eq(["rw"])

      sdb2 = current_graph.find_by_name("/dev/sdb2")
      expect(sdb2.filesystem.mount_path).to eq("/bar")
      expect(sdb2.filesystem.mount_options).to eq(["ro"])
    end

    it "formats the devices with the filesystem type indicated in the fstab" do
      subject.import_mount_points

      sda2 = current_graph.find_by_name("/dev/sda2")
      expect(sda2.filesystem.type).to eq(ext3)

      sdb2 = current_graph.find_by_name("/dev/sdb2")
      expect(sdb2.filesystem.type).to eq(ext4)
    end

    it "does not modify other devices" do
      devices_before = current_graph.partitions.select do |device|
        !["/dev/sda2", "/dev/sdb2"].include?(device.name)
      end

      subject.import_mount_points

      devices = current_graph.partitions.select do |device|
        !["/dev/sda2", "/dev/sdb2"].include?(device.name)
      end

      expect(devices).to eq(devices_before)
    end

    context "when the fstab contains a NFS entry" do
      before do
        Y2Storage::Filesystems::Nfs.create(system_graph, "srv", "/home/a")
      end

      let(:entries) do
        [
          fstab_entry("srv:/home/a", "/foo", "", ["rw"], 0, 0)
        ]
      end

      it "imports mount point and mount options for the NFS entry" do
        subject.import_mount_points

        nfs = Y2Storage::Filesystems::Nfs.find_by_server_and_path(current_graph, "srv", "/home/a")

        expect(nfs.mount_path).to eq("/foo")
        expect(nfs.mount_options).to eq(["rw"])
      end
    end
  end
end
