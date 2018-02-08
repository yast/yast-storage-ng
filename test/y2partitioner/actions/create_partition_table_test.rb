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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/actions/create_partition_table"

describe Y2Partitioner::Actions::CreatePartitionTable do
  let(:select_dialog) { Y2Partitioner::Dialogs::PartitionTableType }

  context "With a PC with 2 disks with some partitions" do
    before do
      devicegraph_stub("mixed_disks_btrfs.yml")
    end

    subject(:action) { described_class.new(disk_name) }
    let(:disk) { Y2Partitioner::DeviceGraphs.instance.current.find_by_name(disk_name) }

    let(:disk_name) { "/dev/sdb" }
    let(:original_partitions) do
      ["/dev/sdb1", "/dev/sdb2", "/dev/sdb3", "/dev/sdb4", "/dev/sdb5", "/dev/sdb6", "/dev/sdb7"]
    end

    describe "#run" do
      before do
        allow(select_dialog).to receive(:run).and_return dialog_result
      end
      let(:dialog_result) { :back }

      it "displays a dialog to select the partition table type" do
        expect(select_dialog).to receive(:run).and_return dialog_result
        action.run
      end

      context "if the user goes back in the type selection" do
        let(:dialog_result) { :back }

        it "leaves the disk untouched" do
          action.run
          expect(disk.partitions.map(&:name).sort).to eq original_partitions
        end

        it "returns :back" do
          expect(action.run).to eq :back
        end
      end

      context "if the user proceeds beyond the type selection" do
        let(:dialog_result) { :next }

        before do
          allow(Yast::Popup).to receive(:YesNo).and_return confirmed
        end
        let(:confirmed) { false }

        it "shows a confirmation dialog" do
          expect(Yast::Popup).to receive(:YesNo)
          action.run
        end

        context "and the user confirms" do
          let(:confirmed) { true }

          before { action.controller.type = type }

          context "and the user selected GPT" do
            let(:type) { Y2Storage::PartitionTables::Type::GPT }

            it "replaces the previous partition table with a new empty GPT" do
              action.run
              expect(disk.partition_table.type).to eq type
              expect(disk.partitions).to be_empty
            end

            it "returns :finish" do
              expect(action.run).to eq :finish
            end
          end

          context "and the user did selected MSDOS" do
            let(:type) { Y2Storage::PartitionTables::Type::MSDOS }

            it "replaces the previous partition table with a new empty MSDOS one" do
              action.run
              expect(disk.partition_table.type).to eq type
              expect(disk.partitions).to be_empty
            end

            it "returns :finish" do
              expect(action.run).to eq :finish
            end
          end
        end

        context "and the user rejects" do
          let(:confirmed) { false }

          it "leaves the disk untouched" do
            action.run
            expect(disk.partitions.map(&:name).sort).to eq original_partitions
          end

          it "returns :back" do
            expect(action.run).to eq :back
          end
        end
      end
    end

    describe "#run?" do
      context "With an existing disk" do
        let(:disk_name) { "/dev/sda" }
        it "Reports that it can run the workflow" do
          expect(Yast::Popup).not_to receive(:Error)
          expect(subject.controller.disk).not_to be_nil
          expect(subject.send(:run?)).to be true
        end
      end

      context "With a nonexistent disk" do
        let(:disk_name) { "/dev/doesnotexist" }
        it "Reports that it can't run the workflow" do
          expect(Yast::Popup).to receive(:Error)
          expect(subject.send(:run?)).to be false
        end
      end
    end
  end

  context "With a S/390 DASD with one partition" do
    before do
      devicegraph_stub("dasd_50GiB.yml")
    end

    subject(:action) { described_class.new(disk_name) }
    let(:dasd) { Y2Partitioner::DeviceGraphs.instance.current.find_by_name(disk_name) }

    let(:disk_name) { "/dev/sda" }
    let(:original_partitions) { ["/dev/sda1"] }

    describe "#run" do
      before do
        allow(Yast::Popup).to receive(:YesNo).and_return confirmed
      end
      let(:confirmed) { false }

      it "does not display a dialog to select the partition table type" do
        expect(select_dialog).to_not receive(:run)
        action.run
      end

      it "shows a confirmation dialog" do
        expect(Yast::Popup).to receive(:YesNo)
        action.run
      end

      context "if the user confirms" do
        let(:confirmed) { true }

        it "replaces the previous partition table with a new empty GPT one" do
          action.run
          expect(dasd.partition_table.type).to eq Y2Storage::PartitionTables::Type::DASD
          expect(dasd.partitions).to be_empty
        end

        it "returns :finish" do
          expect(action.run).to eq :finish
        end
      end

      context "if the user rejects" do
        let(:confirmed) { false }

        it "leaves the disk untouched" do
          action.run
          expect(dasd.partitions.map(&:name).sort).to eq original_partitions
        end

        it "returns :back" do
          expect(action.run).to eq :back
        end
      end
    end
  end
end
