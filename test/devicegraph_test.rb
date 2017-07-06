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
        probed = Y2Storage::StorageManager.instance.y2storage_probed
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

  describe "#is_filesystem_in_network?" do
    context "when filesystem is in network" do
      before {allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem)
        .to receive(:in_network?).and_return(true)}
      let(:devicegraph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }
      
      it "returns true" do
        expect(devicegraph.is_filesystem_in_network?("/")).to eq true
      end
    end
    
    context "when filesystem is not in network" do
      before {allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem)
        .to receive(:in_network?).and_return(false)}
      let(:devicegraph) { Y2Storage::Devicegraph.new_from_file(input_file_for("mixed_disks")) }
      
      it "returns false" do
        expect(devicegraph.is_filesystem_in_network?("/")).to eq false
      end
    end
  end
end
