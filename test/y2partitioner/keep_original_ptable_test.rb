#!/usr/bin/env rspec
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

require_relative "test_helper"
require "y2storage"
require "y2partitioner/actions/controllers/md"

describe "adding a disk to an MD and removing it again" do
  before { devicegraph_stub("complex-lvm-encrypt") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:md_controller) do
    Y2Partitioner::Actions::Controllers::Md.new
  end
  let(:md) { md_controller.md }

  context "for a disk with an existing partition table" do
    subject(:disk) do
      disk = current_graph.find_by_name("/dev/sdf")
      disk.partition_table.delete_partition("/dev/sdf1")
      disk
    end

    it "keeps the original partition table" do
      initial_sid = disk.partition_table.sid
      expect(disk.partition_table.type.to_sym).to eq :gpt

      # Add the device and ensure it was added
      md_controller.add_device(disk)
      expect(disk.partition_table).to be_nil
      expect(disk.md).to eq md

      md_controller.remove_device(disk)

      expect(disk.partition_table.sid).to eq initial_sid
      expect(disk.partition_table.type.to_sym).to eq :gpt
    end

    it "does not restore original partitions" do
      md_controller.add_device(disk)
      expect(disk.partition_table).to be_nil

      md_controller.remove_device(disk)

      expect(disk.partition_table.partitions).to be_empty
    end
  end

  context "for a disk with a newly added partition table" do
    subject(:disk) do
      disk = current_graph.find_by_name("/dev/sdb")
      disk.create_partition_table(Y2Storage::PartitionTables::Type::MSDOS)
      disk
    end

    it "keeps the original partition table" do
      initial_sid = disk.partition_table.sid
      expect(disk.partition_table.type.to_sym).to eq :msdos

      # Add the device and ensure it was added
      md_controller.add_device(disk)
      expect(disk.partition_table).to be_nil
      expect(disk.md).to eq md

      md_controller.remove_device(disk)

      expect(disk.partition_table.sid).to eq initial_sid
      expect(disk.partition_table.type.to_sym).to eq :msdos
    end
  end

  context "for a disk with no partition table" do
    subject(:disk) { current_graph.find_by_name("/dev/sdb") }

    it "leaves the disk empty again" do
      expect(disk.descendants).to be_empty

      # Add the device and ensure it was added
      md_controller.add_device(disk)
      expect(disk.md).to eq md

      md_controller.remove_device(disk)

      expect(disk.descendants).to be_empty
    end
  end
end
