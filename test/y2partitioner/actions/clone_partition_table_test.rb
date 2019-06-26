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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/actions/clone_partition_table"

describe Y2Partitioner::Actions::ClonePartitionTable do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(device) }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show)
    end

    RSpec.shared_examples "validation_error" do
      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show)
        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when the device has no partition table" do
      let(:device_name) { "/dev/sda" }

      before do
        device.remove_descendants
      end

      context "and there are no suitable devices for cloning" do
        let(:scenario) { "empty_hard_disk_15GiB.yml" }

        include_examples "validation_error"
      end

      context "and there are suitable devices for cloning" do
        let(:scenario) { "mixed_disks.yml" }

        include_examples "validation_error"
      end
    end

    context "when the device has partition table" do
      let(:scenario) { "mixed_disks.yml" }

      context "and there are no suitable devices for cloning" do
        let(:device_name) { "/dev/sdb" }

        include_examples "validation_error"
      end

      context "and there are suitable devices for cloning" do
        let(:device_name) { "/dev/sda" }

        before do
          allow(Y2Partitioner::Dialogs::PartitionTableClone).to receive(:run).and_return(result)
        end

        let(:result) { :ok }

        it "opens the dialog for cloning the device" do
          expect(Y2Partitioner::Dialogs::PartitionTableClone).to receive(:run)
          subject.run
        end

        context "and the dialog is not accepted" do
          let(:result) { :cancel }

          it "returns the dialog result" do
            expect(subject.run).to eq(result)
          end
        end

        context "and the dialog is accepted" do
          let(:result) { :ok }

          before do
            allow_any_instance_of(Y2Partitioner::Actions::Controllers::ClonePartitionTable)
              .to receive(:selected_devices_for_cloning).and_return(selected_devices)
          end

          let(:selected_devices) { [sdb, sdc] }

          let(:sdb) { current_graph.find_by_name("/dev/sdb") }

          let(:sdc) { current_graph.find_by_name("/dev/sdc") }

          # More exhaustive tests for cloning can be found in the tests for
          # Y2Partitioner::Actions::Controllers::ClonePartitionTable
          it "clones the device into selected devices" do
            expect(sdb.partitions.size).to_not eq(device.partitions.size)
            expect(sdc.partitions).to be_empty

            subject.run

            expect(sdb.partitions.size).to eq(device.partitions.size)
            expect(sdc.partitions.size).to eq(device.partitions.size)
          end

          it "returns :finish" do
            expect(subject.run).to eq(:finish)
          end
        end
      end
    end
  end
end
