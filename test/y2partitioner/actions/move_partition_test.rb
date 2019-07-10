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

require_relative "../test_helper"
require "y2partitioner/device_graphs"
require "y2partitioner/actions/move_partition"

describe Y2Partitioner::Actions::MovePartition do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(partition) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:partition) { Y2Storage::BlkDevice.find_by_name(current_graph, device_name) }

  let(:scenario) { "mixed_disks" }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show)
    end

    context "when the device is not a partition" do
      let(:device_name) { "/dev/sda" }

      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show).with(/cannot be moved/, anything)

        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when the partition is an extended partition" do
      let(:device_name) { "/dev/sdb4" }

      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show).with(/extended partition cannot be moved/, anything)

        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when the partition already exists on disk" do
      let(:device_name) { "/dev/sda1" }

      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show).with(/already created on disk/, anything)

        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when there is no space to move the partition" do
      before do
        # Create a partition using all the free space
        sdc = current_graph.find_by_name("/dev/sdc")
        slot = sdc.partition_table.unused_partition_slots.first
        sdc.partition_table.create_partition(slot.name, slot.region, Y2Storage::PartitionType::PRIMARY)
      end

      let(:device_name) { "/dev/sdc1" }

      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show).with(/No space to move/, anything)

        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when the partition can be moved" do
      # "mixed_disks" is loaded after probing a basic scenario, so all devices there can
      # be used as new devices (not probed).
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:current_graph) { devicegraph_from("mixed_disks") }

      def delete_partitions(*partition_names)
        partitions = partition_names.map { |n| current_graph.find_by_name(n) }

        partitions.each do |partition|
          partition_table = partition.partition_table
          partition_table.delete_partition(partition)
        end
      end

      before do
        allow(Y2Partitioner::Dialogs::PartitionMove).to receive(:new).and_return(move_dialog)

        allow(move_dialog).to receive(:run).and_return(move_dialog_result)
        allow(move_dialog).to receive(:selected_movement).and_return(selected_movement)

        delete_partitions(*deleted_partitions)
      end

      let(:move_dialog) { instance_double(Y2Partitioner::Dialogs::PartitionMove) }

      let(:move_dialog_result) { :cancel }

      let(:selected_movement) { nil }

      let(:deleted_partitions) { [] }

      context "and it is a primary partition" do
        context "and there is adjacent free space before and after" do
          let(:deleted_partitions) { ["/dev/sdb1", "/dev/sdb3"] }

          # Former /dev/sdb2
          let(:device_name) { "/dev/sdb1" }

          it "asks to the user whether to move forward or backward" do
            expect(Y2Partitioner::Dialogs::PartitionMove).to receive(:new).with(partition, :both)
            subject.run
          end
        end

        context "and there is no adjacent free space after" do
          let(:deleted_partitions) { ["/dev/sdb1"] }

          # Former /dev/sdb2
          let(:device_name) { "/dev/sdb1" }

          it "asks to the user whether to move forward" do
            expect(Y2Partitioner::Dialogs::PartitionMove).to receive(:new).with(partition, :forward)
            subject.run
          end
        end

        context "and there is no adjacent free space before" do
          let(:deleted_partitions) { ["/dev/sdb3"] }

          let(:device_name) { "/dev/sdb2" }

          it "asks to the user whether to move backward" do
            expect(Y2Partitioner::Dialogs::PartitionMove).to receive(:new).with(partition, :backward)
            subject.run
          end
        end
      end

      context "and it is a logical partition" do
        context "and there is adjacent free space before and after, inside the extended partition" do
          let(:deleted_partitions) { ["/dev/sdb5", "/dev/sdb7"] }

          # Former /dev/sdb6
          let(:device_name) { "/dev/sdb5" }

          it "asks to the user whether to move forward or backward" do
            expect(Y2Partitioner::Dialogs::PartitionMove).to receive(:new).with(partition, :both)
            subject.run
          end
        end

        context "and there is no adjacent free space after, inside the extended partition" do
          let(:deleted_partitions) { ["/dev/sdb5"] }

          # Former /dev/sdb6
          let(:device_name) { "/dev/sdb5" }

          it "asks to the user whether to move forward" do
            expect(Y2Partitioner::Dialogs::PartitionMove).to receive(:new).with(partition, :forward)
            subject.run
          end
        end

        context "and there is no adjacent free space before, inside the extended partition" do
          # Delete primary partition (/dev/sdb3) just before the extended partition
          let(:deleted_partitions) { ["/dev/sdb3", "/dev/sdb6"] }

          let(:device_name) { "/dev/sdb5" }

          it "asks to the user whether to move backward" do
            expect(Y2Partitioner::Dialogs::PartitionMove).to receive(:new).with(partition, :backward)
            subject.run
          end
        end
      end

      context "and the user declines to move" do
        let(:deleted_partitions) { ["/dev/sdb1", "/dev/sdb3"] }

        # Former /dev/sdb2
        let(:device_name) { "/dev/sdb1" }

        let(:move_dialog_result) { :cancel }

        it "does not move the partition" do
          initial_region = partition.region.dup
          subject.run

          expect(partition.region).to eq(initial_region)
        end

        it "returns :cancel" do
          expect(subject.run).to eq(:cancel)
        end
      end

      context "and the user accepts to move" do
        let(:deleted_partitions) { ["/dev/sdb1", "/dev/sdb3"] }

        # Former /dev/sdb2
        let(:device_name) { "/dev/sdb1" }

        let(:move_dialog_result) { :ok }

        let(:selected_movement) { :forward }

        it "moves the partition" do
          initial_region = partition.region.dup
          subject.run

          expect(partition.region).to_not eq(initial_region)
        end

        it "returns :finish" do
          expect(subject.run).to eq(:finish)
        end

        context "and the partition is moved forward" do
          let(:selected_movement) { :forward }

          it "places the partition at the beginning of the previous adjacent free space" do
            ptable = partition.partition_table
            free_slots = ptable.unused_partition_slots(Y2Storage::AlignPolicy::ALIGN_START_AND_END)
            previous_slot = free_slots.first

            subject.run

            expect(partition.region.start).to eq(previous_slot.region.start)
          end

          it "does not change the partition size" do
            size_before = partition.size

            subject.run

            expect(partition.size).to eq(size_before)
          end
        end

        context "and the partition is moved backward" do
          let(:selected_movement) { :backward }

          it "places the partition at the end of the next adjacent free space" do
            ptable = partition.partition_table
            free_slots = ptable.unused_partition_slots(Y2Storage::AlignPolicy::ALIGN_START_AND_END)
            next_slot = free_slots.at(1)

            subject.run

            expect(partition.region.end).to eq(next_slot.region.end)
          end

          it "does not change the partition size" do
            size_before = partition.size

            subject.run

            expect(partition.size).to eq(size_before)
          end
        end
      end
    end
  end
end
