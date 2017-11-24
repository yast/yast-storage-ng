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

describe Y2Storage::Devicegraph do
  describe "#actiongraph" do
    def with_sda2_deleted(initial_graph)
      graph = initial_graph.dup
      Y2Storage::Disk.find_by_name(graph, "/dev/sda").partition_table.delete_partition("/dev/sda2")
      graph
    end

    context "if both devicegraphs are equivalent" do
      before { Y2Storage::StorageManager.create_test_instance }

      let(:initial_graph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }
      subject(:devicegraph) { initial_graph.dup }

      it "returns an empty actiongraph" do
        result = devicegraph.actiongraph(from: initial_graph)
        expect(result).to be_a Y2Storage::Actiongraph
        expect(result).to be_empty
      end
    end

    context "if both devicegraphs are not equivalent" do
      before { Y2Storage::StorageManager.create_test_instance }

      let(:initial_graph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }
      subject(:devicegraph) { with_sda2_deleted(initial_graph) }

      it "returns an actiongraph with the needed actions" do
        result = devicegraph.actiongraph(from: initial_graph)
        expect(result).to be_a Y2Storage::Actiongraph
        expect(result).to_not be_empty
      end
    end

    context "if no initial devicegraph is provided" do
      before { fake_scenario("mixed_disks") }

      subject(:devicegraph) { with_sda2_deleted(fake_devicegraph) }

      it "uses the probed devicegraph as starting point" do
        probed = Y2Storage::StorageManager.instance.probed
        actiongraph1 = devicegraph.actiongraph(from: probed)
        actiongraph2 = devicegraph.actiongraph
        expect(actiongraph1.commit_actions_as_strings).to eq(actiongraph2.commit_actions_as_strings)
      end
    end
  end

  describe "#blk_filesystems" do
    before { fake_scenario("complex-lvm-encrypt") }
    subject(:list) { fake_devicegraph.blk_filesystems }
    let(:device_names) { list.map { |i| i.blk_devices.first.name } }

    it "returns a array of block filesystems" do
      expect(list).to be_a Array
      expect(list.map { |i| i.is?(:blk_filesystem) }).to all(be(true))
    end

    it "finds the filesystems on plain partitions" do
      expect(device_names).to include("/dev/sda1")
      expect(device_names).to include("/dev/sda2")
      expect(device_names).to include("/dev/sdf1")
    end

    it "finds the filesystems on encrypted partitions" do
      expect(device_names).to include("/dev/mapper/cr_sda4")
    end

    it "finds the filesystems on plain LVs" do
      expect(device_names).to include("/dev/vg0/lv1")
      expect(device_names).to include("/dev/vg0/lv2")
      expect(device_names).to include("/dev/vg1/lv1")
    end

    it "finds the filesystems on encrypted LVs" do
      expect(device_names).to include("/dev/mapper/cr_vg1_lv2")
    end
  end

  describe "#filesystems" do
    before { fake_scenario("complex-lvm-encrypt") }
    subject(:list) { fake_devicegraph.filesystems }

    it "returns a array of filesystems" do
      expect(list).to be_a Array
      expect(list.map { |i| i.is?(:filesystem) }).to all(be(true))
    end

    it "finds all the filesystems" do
      expect(list.size).to eq 9
    end
  end

  describe "#lvm_pvs" do
    before { fake_scenario("complex-lvm-encrypt") }
    subject(:list) { fake_devicegraph.lvm_pvs }
    let(:device_names) { list.map { |i| i.blk_device.name } }

    it "returns a array of PVs" do
      expect(list).to be_a Array
      expect(list.map { |i| i.is?(:lvm_pv) }).to all(be(true))
    end

    it "finds the PVs on plain partitions" do
      expect(device_names).to include("/dev/sde2")
    end

    it "finds the PVs on encrypted partitions" do
      expect(device_names).to include("/dev/mapper/cr_sde1")
    end

    it "finds the PVs on plain disks" do
      expect(device_names).to include("/dev/sdg")
    end

    it "finds the PVs on encrypted disks" do
      expect(device_names).to include("/dev/mapper/cr_sdd")
    end
  end

  describe "#filesystem_in_network?" do
    before do
      allow(devicegraph).to receive(:filesystems).and_return([filesystem])
    end
    let(:blk_device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }
    let(:filesystem) { blk_device.blk_filesystem }
    let(:devicegraph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }
    let(:dev_name) { "/dev/sdb2" }

    context "when filesystem is in network" do
      before do
        allow(filesystem).to receive(:in_network?).and_return(true)
      end

      it "returns true" do
        expect(devicegraph.filesystem_in_network?("/")).to eq true
      end
    end

    context "when filesystem is not in network" do
      before do
        allow(filesystem).to receive(:in_network?).and_return(false)
      end
      let(:devicegraph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }

      it "returns false" do
        expect(devicegraph.filesystem_in_network?("/")).to eq false
      end
    end

    context "when mountpoint does not exist" do
      before do
        allow(filesystem).to receive(:in_network?).and_return(true)
      end
      let(:devicegraph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }

      it "returns false" do
        expect(devicegraph.filesystem_in_network?("no_mountpoint")).to eq false
      end
    end
  end

  describe "#disk_devices" do
    before { fake_scenario(scenario) }
    subject(:graph) { fake_devicegraph }

    def less_than_next(device, collection)
      next_dev = collection[collection.index(device) + 1]
      next_dev.nil? || device.compare_by_name(next_dev) < 0
    end

    context "if there are no multi-disk devices" do
      let(:scenario) { "autoyast_drive_examples" }

      it "returns an array of devices" do
        expect(graph.disk_devices).to be_an Array
        expect(graph.disk_devices).to all(be_a(Y2Storage::Device))
      end

      it "includes all disks and DASDs sorted by name" do
        expect(graph.disk_devices.map(&:name)).to eq [
          "/dev/dasda", "/dev/dasdb", "/dev/nvme0n1", "/dev/sda", "/dev/sdb",
          "/dev/sdc", "/dev/sdd", "/dev/sdf", "/dev/sdh", "/dev/sdaa"
        ]
      end

      context "even if Disk.all and Dasd.all return unsorted arrays" do
        before do
          allow(Y2Storage::Disk).to receive(:all) do |devicegraph|
            # Let's shuffle things a bit
            shuffle(Y2Storage::Partitionable.all(devicegraph).select { |i| i.is?(:disk) })
          end
          dasda = Y2Storage::Dasd.find_by_name(fake_devicegraph, "/dev/dasda")
          dasdb = Y2Storage::Dasd.find_by_name(fake_devicegraph, "/dev/dasdb")
          allow(Y2Storage::Dasd).to receive(:all).and_return [dasdb, dasda]
        end

        it "returns an array sorted by name" do
          expect(graph.disk_devices.map(&:name)).to eq [
            "/dev/dasda", "/dev/dasdb", "/dev/nvme0n1", "/dev/sda", "/dev/sdb",
            "/dev/sdc", "/dev/sdd", "/dev/sdf", "/dev/sdh", "/dev/sdaa"
          ]
        end
      end
    end

    context "if there are multipath devices" do
      let(:scenario) { "empty-dasd-and-multipath.xml" }

      it "returns a sorted array of devices" do
        devices = graph.disk_devices
        expect(devices).to be_an Array
        expect(devices).to all(be_a(Y2Storage::Device))
        expect(devices).to all(satisfy { |dev| less_than_next(dev, devices) })
      end

      it "includes all the multipath devices" do
        expect(graph.disk_devices.map(&:name)).to include(
          "/dev/mapper/36005076305ffc73a00000000000013b4",
          "/dev/mapper/36005076305ffc73a00000000000013b5"
        )
      end

      it "includes all disks and DASDs that are not part of a multipath" do
        expect(graph.disk_devices.map(&:name)).to include("/dev/dasdb", "/dev/sde")
      end

      it "does not include individual disks and DASDs from the multipaths" do
        expect(graph.disk_devices.map(&:name)).to_not include(
          "/dev/sda", "/dev/sdb", "/dev/sdc", "/dev/sdd"
        )
      end

      context "even if Disk.all and Multipath.all return unsorted arrays" do
        # Let's shuffle things a bit
        before do
          allow(Y2Storage::Disk).to receive(:all) do |devicegraph|
            shuffle(Y2Storage::Partitionable.all(devicegraph).select { |i| i.is?(:disk) })
          end
          allow(Y2Storage::Multipath).to receive(:all) do |devicegraph|
            shuffle(Y2Storage::Partitionable.all(devicegraph).select { |i| i.is?(:multipath) })
          end
        end

        it "returns an array sorted by name" do
          devices = graph.disk_devices
          expect(devices).to all(satisfy { |dev| less_than_next(dev, devices) })
        end
      end
    end

    context "if there are DM RAIDs" do
      let(:scenario) { "empty-dm_raids.xml" }

      it "returns a sorted array of devices" do
        devices = graph.disk_devices
        expect(devices).to be_an Array
        expect(devices).to all(be_a(Y2Storage::Device))
        expect(devices).to all(satisfy { |dev| less_than_next(dev, devices) })
      end

      it "includes all the DM RAIDs" do
        expect(graph.disk_devices.map(&:name)).to include(
          "/dev/mapper/isw_ddgdcbibhd_test1", "/dev/mapper/isw_ddgdcbibhd_test2"
        )
      end

      it "includes all disks and DASDs that are not part of an MD RAID" do
        expect(graph.disk_devices.map(&:name)).to include("/dev/sda")
      end

      it "does not include individual disks and DASDs from the MD RAID" do
        expect(graph.disk_devices.map(&:name)).to_not include("/dev/sdb", "/dev/sdc")
      end
    end
  end

  describe "#remove_md" do
    subject(:devicegraph) { Y2Storage::StorageManager.instance.staging }

    before do
      fake_scenario("md_raid.xml")

      # Create a Vg over the md raid
      md = Y2Storage::Md.find_by_name(devicegraph, md_name)
      md.remove_descendants

      vg = Y2Storage::LvmVg.create(devicegraph, vg_name)
      vg.add_lvm_pv(md)
      vg.create_lvm_lv("lv1", Y2Storage::DiskSize.GiB(1))
    end

    let(:md_name) { "/dev/md/md0" }

    let(:vg_name) { "vg0" }

    it "removes the given md device" do
      md = Y2Storage::Md.find_by_name(devicegraph, md_name)
      expect(md).to_not be_nil

      devicegraph.remove_md(md)

      md = Y2Storage::Md.find_by_name(devicegraph, md_name)
      expect(md).to be_nil
    end

    it "removes all md descendants" do
      md = Y2Storage::Md.find_by_name(devicegraph, md_name)
      descendants_sid = md.descendants.map(&:sid)

      expect(descendants_sid).to_not be_empty

      devicegraph.remove_md(md)

      existing_descendants = descendants_sid.map { |sid| devicegraph.find_device(sid) }.compact
      expect(existing_descendants).to be_empty
    end

    context "when the md does not exist in the devicegraph" do
      before do
        Y2Storage::Md.create(other_devicegraph, md1_name)
      end

      let(:other_devicegraph) { devicegraph.dup }

      let(:md1_name) { "/dev/md/md1" }

      it "raises an exception and does not remove the md" do
        md1 = Y2Storage::Md.find_by_name(other_devicegraph, md1_name)

        expect { devicegraph.remove_md(md1) }.to raise_error(ArgumentError)
        expect(Y2Storage::Md.find_by_name(other_devicegraph, md1_name)).to_not be_nil
      end
    end
  end

  describe "#to_xml" do
    before { fake_scenario("empty_hard_disk_50GiB") }

    subject(:devicegraph) { fake_devicegraph }

    def create_partition(disk)
      disk.ensure_partition_table
      slot = disk.partition_table.unused_partition_slots.first
      disk.partition_table.create_partition(slot.name, slot.region, Y2Storage::PartitionType::PRIMARY)
    end

    it "returns a string" do
      expect(devicegraph.to_xml).to be_a(String)
    end

    it "contains the xml representation of the devicegraph" do
      expect(devicegraph.to_xml).to match(/^\<\?xml/)
      expect(devicegraph.to_xml.scan(/\<Disk\>/).size).to eq(1)
      expect(devicegraph.to_xml.scan(/\<Partition\>/).size).to eq(0)

      create_partition(devicegraph.disks.first)

      expect(devicegraph.to_xml.scan(/\<Partition\>/).size).to eq(1)
    end
  end
end
