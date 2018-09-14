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
  # Defined as method instead of let clause because using let it points to the
  # current devicegraph at the moment to call #current_graph for first time, but
  # after a transaction, the current devicegraph could change. The tests need to
  # always access to the current devicegraph, even after a transaction.
  def current_graph
    Y2Partitioner::DeviceGraphs.instance.current
  end

  before do
    devicegraph_stub(scenario)

    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)
    allow(subject).to receive(:skip_steps)
  end

  subject(:action) { described_class.new(disk) }

  let(:disk) { Y2Storage::Disk.find_by_name(current_graph, disk_name) }

  describe "#run" do
    let(:scenario) { "lvm-two-vgs.yml" }

    let(:disk_name) { "/dev/sda" }

    # Regression test
    it "uses the device belonging to the current devicegraph" do
      # Only to finish
      allow(subject).to receive(:run?).and_return(false)

      initial_graph = current_graph

      expect(Y2Partitioner::Actions::Controllers::AddPartition).to receive(:new) do |disk_name|
        # Modifies used device
        disk = Y2Storage::BlkDevice.find_by_name(current_graph, disk_name)
        disk.remove_descendants

        # Initial device is not modified
        initial_disk = Y2Storage::BlkDevice.find_by_name(initial_graph, disk_name)
        expect(initial_disk.descendants).to_not be_empty
      end

      subject.run
    end

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

    context "if called for a StrayBlkDevice (Xen virtual partition)" do
      let(:scenario) { "xen-partitions.xml" }

      let(:disk) { Y2Storage::BlkDevice.find_by_name(current_graph, "/dev/xvda1") }

      it "shows an error popup" do
        expect(Yast::Popup).to receive(:Error)
        action.run
      end

      it "quits returning :back" do
        expect(action.run).to eq(:back)
      end

      it "does not create any partition" do
        partitions_before = current_graph.partitions
        action.run
        partitions_after = current_graph.partitions
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
          allow(Yast::Popup).to receive(:YesNo).and_return(false)
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
          allow(Yast::Popup).to receive(:YesNo).and_return(true)

          allow(Y2Partitioner::Actions::Controllers::AddPartition).to receive(:new).with(disk_name)
            .and_return(controller)
          # Only to finish
          allow(Y2Partitioner::Dialogs::PartitionType).to receive(:run).and_return(:abort)
          allow(controller).to receive(:available_partition_types).and_return(available_types)
        end

        let(:controller) { Y2Partitioner::Actions::Controllers::AddPartition.new(disk_name) }
        let(:available_types) { Y2Storage::PartitionType.all }

        it "removes the filesystem" do
          expect(controller).to receive(:delete_filesystem)
          action.run
        end
      end
    end

    context "if the user goes forward through all the dialogs" do
      let(:scenario) { "empty_hard_disk_50GiB.yml" }

      let(:disk_name) { "/dev/sda" }

      before do
        allow(Y2Partitioner::Actions::Controllers::AddPartition).to receive(:new).with(disk_name)
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

      let(:controller) { Y2Partitioner::Actions::Controllers::AddPartition.new(disk_name) }

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

    context "if some dialog is skipped and then the user goes back" do
      let(:scenario) { "empty_hard_disk_50GiB.yml" }
      let(:disk_name) { "/dev/sda" }
      let(:available_types) { [Y2Storage::PartitionType.new("primary")] }
      let(:controller) { Y2Partitioner::Actions::Controllers::AddPartition.new(disk_name) }

      before do
        allow(controller).to receive(:available_partition_types).and_return(available_types)
        allow(subject).to receive(:type).and_return(:next)
        allow(Y2Partitioner::Dialogs::PartitionSize).to receive(:run).and_return(:back)
        allow(Y2Partitioner::Actions::Controllers::AddPartition).to receive(:new).with(disk_name)
          .and_return(controller)
        allow(subject).to receive(:skip_steps).and_call_original
      end

      it "does not run again skipped dialogs" do
        expect(subject).to receive(:type).once.and_return(:next)
        action.run
      end

      it "returns :back" do
        expect(action.run).to eq :back
      end
    end
  end

  describe "#type" do
    let(:scenario) { "empty_hard_disk_50GiB.yml" }
    let(:disk_name) { "/dev/sda" }
    let(:controller) { Y2Partitioner::Actions::Controllers::AddPartition.new(disk_name) }
    let(:available_types) { Y2Storage::PartitionType.all }

    before do
      allow(controller).to receive(:available_partition_types).and_return(available_types)
      subject.instance_variable_set(:@controller, controller)
    end

    context "when there is no partition types available" do
      let(:available_types) { [] }
      it "raises an error" do
        expect { subject.type }.to raise_error("No partition type possible")
      end
    end

    context "when there is only one partition type available" do
      let(:available_types) { [Y2Storage::PartitionType.new("extended")] }
      it "uses it as the type for the new partition" do
        expect(controller).to receive(:type=).with(available_types.first)
        subject.type
      end
    end

    context "when there is more than one partition type available" do
      it "runs the dialogs for choising the partition type" do
        expect(Y2Partitioner::Dialogs::PartitionType).to receive(:run)
        subject.type
      end
    end
  end
end
