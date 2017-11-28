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

require_relative "../test_helper"
require "y2partitioner/device_graphs"
require "y2partitioner/actions/add_partition"
require "y2partitioner/dialogs"

describe Y2Partitioner::Actions::AddPartition do
  before do
    devicegraph_stub(scenario)

    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)
  end

  subject(:action) { described_class.new(disk) }

  let(:disk) { Y2Storage::Disk.find_by_name(current_graph, disk_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    context "if it is not possible to create a new partition on the disk" do
      let(:scenario) { "lvm-two-vgs.yml" }

      let(:disk_name) { "/dev/sda" }

      it "shows an error popup" do
        expect(Yast::Popup).to receive(:Error)
        action.run
      end

      it "quits returning :back" do
        expect(action.run).to eq(:back)
      end

      it "does not create any partition" do
        partitions_before = Y2Storage::Disk.find_by_name(current_graph, disk_name).partitions
        action.run
        partitions_after = Y2Storage::Disk.find_by_name(current_graph, disk_name).partitions
        expect(partitions_after).to eq(partitions_before)
      end
    end

    context "if the disk is in use" do
      let(:scenario) { "empty_hard_disk_50GiB.yml" }

      let(:disk_name) { "/dev/sda" }

      before do
        md = Y2Storage::Md.create(current_graph, "/dev/md0")
        md.add_device(disk)
      end

      it "shows an error popup" do
        expect(Yast::Popup).to receive(:Error)
        action.run
      end

      it "quits returning :back" do
        expect(action.run).to eq(:back)
      end

      it "does not create any partition" do
        partitions_before = Y2Storage::Disk.find_by_name(current_graph, disk_name).partitions
        action.run
        partitions_after = Y2Storage::Disk.find_by_name(current_graph, disk_name).partitions
        expect(partitions_after).to eq(partitions_before)
      end
    end

    context "if the disk is formatted" do
      let(:scenario) { "empty_hard_disk_50GiB.yml" }

      let(:disk_name) { "/dev/sda" }

      before do
        disk.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
      end

      it "shows an confirm popup" do
        expect(Yast::Popup).to receive(:YesNo)
        action.run
      end

      context "when the confirm popup is not accepted" do
        before do
          expect(Yast::Popup).to receive(:YesNo).and_return(false)
        end

        it "quits returning :back" do
          expect(action.run).to eq(:back)
        end

        it "does not create any partition" do
          partitions_before = Y2Storage::Disk.find_by_name(current_graph, disk_name).partitions
          action.run
          partitions_after = Y2Storage::Disk.find_by_name(current_graph, disk_name).partitions
          expect(partitions_after).to eq(partitions_before)
        end
      end

      context "when the confirm popup is accepted" do
        before do
          expect(Yast::Popup).to receive(:YesNo).and_return(true)
          # Only to finish
          allow(Y2Partitioner::Dialogs::PartitionType).to receive(:run).and_return(:abort)
        end

        it "removes the filesystem" do
          action.run
          disk = Y2Storage::Disk.find_by_name(current_graph, disk_name)
          expect(disk.filesystem).to be_nil
        end
      end
    end

    context "if the user goes forward through all the dialogs" do
      let(:scenario) { "empty_hard_disk_50GiB.yml" }

      let(:disk_name) { "/dev/sda" }

      before do
        allow(Y2Partitioner::Actions::Controllers::Partition).to receive(:new).with(disk_name)
          .and_return(controller)

        allow(controller).to receive(:region).and_return(region)
        allow(controller).to receive(:type).and_return(type)

        allow(Y2Partitioner::Dialogs::PartitionType).to receive(:run).and_return(:next)
        allow(Y2Partitioner::Dialogs::PartitionSize).to receive(:run).and_return(:next)
        allow(Y2Partitioner::Dialogs::PartitionRole).to receive(:run).and_return(:next)
        allow(Y2Partitioner::Dialogs::FormatAndMount).to receive(:run).and_return(:next)
      end

      let(:region) { disk.ensure_partition_table.unused_partition_slots.first.region }

      let(:type) { Y2Storage::PartitionType::PRIMARY }

      let(:controller) { Y2Partitioner::Actions::Controllers::Partition.new(disk_name) }

      it "returns :finish" do
        expect(action.run).to eq(:finish)
      end

      it "creates a partition" do
        partitions = Y2Storage::Disk.find_by_name(current_graph, disk_name).partitions
        expect(partitions).to be_empty

        action.run

        partitions = Y2Storage::Disk.find_by_name(current_graph, disk_name).partitions
        expect(partitions).to_not be_empty
      end
    end

    context "if the user aborts the process at some point" do
      let(:scenario) { "empty_hard_disk_50GiB.yml" }

      let(:disk_name) { "/dev/sda" }

      before do
        allow(Y2Partitioner::Dialogs::PartitionType).to receive(:run).and_return(:next)
        allow(Y2Partitioner::Dialogs::PartitionSize).to receive(:run).and_return(:abort)
      end

      it "returns :abort" do
        expect(action.run).to eq :abort
      end

      it "does not create any partition" do
        partitions_before = Y2Storage::Disk.find_by_name(current_graph, disk_name).partitions
        action.run
        partitions_after = Y2Storage::Disk.find_by_name(current_graph, disk_name).partitions
        expect(partitions_after).to eq(partitions_before)
      end
    end
  end
end
