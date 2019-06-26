#!/usr/bin/env rspec
# Copyright (c) [2017-18] SUSE LLC
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
  # Declare some shortcuts
  let(:dialog_class) { Y2Partitioner::Dialogs::PartitionTableType }
  let(:type_gpt) { Y2Storage::PartitionTables::Type::GPT }
  let(:type_msdos) { Y2Storage::PartitionTables::Type::MSDOS }
  let(:type_dasd) { Y2Storage::PartitionTables::Type::DASD }

  before { devicegraph_stub(scenario) }
  subject(:action) { described_class.new(disk) }
  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:disk) { current_graph.find_by_name(disk_name) }

  describe "#run" do
    before do
      allow(action).to receive(:confirm_recursive_delete).and_return confirmed
    end
    let(:confirmed) { false }

    context "for a disk with some partitions" do
      let(:scenario) { "mixed_disks_btrfs.yml" }
      let(:disk_name) { "/dev/sdb" }
      let(:original_partitions) do
        ["/dev/sdb1", "/dev/sdb2", "/dev/sdb3", "/dev/sdb4", "/dev/sdb5", "/dev/sdb6", "/dev/sdb7"]
      end

      it "shows a confirmation dialog" do
        expect(action).to receive(:confirm_recursive_delete).with(disk, any_args)
        action.run
      end

      context "if the user rejects the confirmation" do
        let(:confirmed) { false }

        it "leaves the disk untouched" do
          action.run
          expect(disk.partitions.map(&:name).sort).to eq original_partitions
        end

        it "returns :back" do
          expect(action.run).to eq :back
        end
      end

      context "if the user confirms" do
        let(:confirmed) { true }

        before do
          allow(dialog_class).to receive(:new).and_return dialog
        end
        let(:dialog) { dialog_class.new(disk, [type_gpt, type_msdos], type_gpt) }

        it "displays a dialog to select the partition table type" do
          expect(dialog_class).to receive(:new).with(disk, [type_gpt, type_msdos], type_gpt)
          expect(dialog).to receive(:run)
          action.run
        end

        context "if the user goes back in the type selection" do
          before { allow(dialog).to receive(:run).and_return :back }

          it "leaves the disk untouched" do
            action.run
            expect(disk.partitions.map(&:name).sort).to eq original_partitions
          end

          it "returns :finish" do
            expect(action.run).to eq :finish
          end
        end

        context "if the user cancels the type selection" do
          before { allow(dialog).to receive(:run).and_return :abort }

          it "leaves the disk untouched" do
            action.run
            expect(disk.partitions.map(&:name).sort).to eq original_partitions
          end

          it "returns :finish" do
            expect(action.run).to eq :finish
          end
        end

        context "if the user selects a type" do
          before { allow(dialog).to receive(:run).and_return :next }

          context "and the user selected GPT" do
            before { allow(dialog).to receive(:selected_type).and_return type_gpt }

            it "replaces the previous partition table with a new empty GPT" do
              action.run
              expect(disk.partition_table.type).to eq type_gpt
              expect(disk.partitions).to be_empty
            end

            it "returns :finish" do
              expect(action.run).to eq :finish
            end
          end

          context "and the user did selected MSDOS" do
            before { allow(dialog).to receive(:selected_type).and_return type_msdos }

            it "replaces the previous partition table with a new empty MSDOS one" do
              action.run
              expect(disk.partition_table.type).to eq type_msdos
              expect(disk.partitions).to be_empty
            end

            it "returns :finish" do
              expect(action.run).to eq :finish
            end
          end
        end
      end
    end

    context "With a S/390 DASD with one partition" do
      let(:scenario) { "dasd_50GiB.yml" }
      let(:disk_name) { "/dev/dasda" }
      let(:original_partitions) { ["/dev/dasda1"] }

      it "shows a confirmation dialog" do
        expect(action).to receive(:confirm_recursive_delete).with(disk, any_args)
        action.run
      end

      context "if the user rejects the confirmation" do
        let(:confirmed) { false }

        it "leaves the DASD untouched" do
          action.run
          expect(disk.partitions.map(&:name).sort).to eq original_partitions
        end

        it "returns :back" do
          expect(action.run).to eq :back
        end
      end

      context "if the user confirms" do
        let(:confirmed) { true }

        it "does not display a dialog to select the partition table type" do
          expect(dialog_class).to_not receive(:run)
          action.run
        end

        it "replaces the previous partition table with a new empty DASD one" do
          action.run
          expect(disk.partition_table.type).to eq type_dasd
          expect(disk.partitions).to be_empty
        end

        it "returns :finish" do
          expect(action.run).to eq :finish
        end
      end
    end

    context "for an unused disk with no partitions" do
      let(:scenario) { "mixed_disks_btrfs.yml" }
      let(:disk_name) { "/dev/sdc" }

      before { allow(dialog_class).to receive(:new).and_return dialog }
      let(:dialog) { dialog_class.new(disk, [type_gpt, type_msdos], type_gpt) }

      it "does not display any confirmation dialog" do
        allow(dialog).to receive(:run)

        expect(action).to_not receive(:confirm_recursive_delete)
        action.run
      end

      it "displays a dialog to select the partition table type" do
        expect(dialog_class).to receive(:new).with(disk, [type_gpt, type_msdos], type_gpt)
        expect(dialog).to receive(:run)
        action.run
      end

      context "if the user goes back in the type selection" do
        before { allow(dialog).to receive(:run).and_return :back }

        it "leaves the disk untouched" do
          ptable_sid = disk.partition_table.sid
          action.run
          expect(disk.partition_table.sid).to eq ptable_sid
        end

        it "returns :finish" do
          expect(action.run).to eq :finish
        end
      end

      context "if the user cancels the type selection" do
        before { allow(dialog).to receive(:run).and_return :abort }

        it "leaves the disk untouched" do
          ptable_sid = disk.partition_table.sid
          action.run
          expect(disk.partition_table.sid).to eq ptable_sid
        end

        it "returns :finish" do
          expect(action.run).to eq :finish
        end
      end

      context "if the user selects a type" do
        before { allow(dialog).to receive(:run).and_return :next }

        context "and the user selected GPT" do
          before { allow(dialog).to receive(:selected_type).and_return type_gpt }

          it "replaces the previous partition table with a new empty GPT" do
            ptable_sid = disk.partition_table.sid
            action.run
            expect(disk.partition_table.type).to eq type_gpt
            expect(disk.partition_table.sid).to_not eq ptable_sid
          end

          it "returns :finish" do
            expect(action.run).to eq :finish
          end
        end

        context "and the user did selected MSDOS" do
          before { allow(dialog).to receive(:selected_type).and_return type_msdos }

          it "replaces the previous partition table with a new empty MSDOS one" do
            ptable_sid = disk.partition_table.sid
            action.run
            expect(disk.partition_table.type).to eq type_msdos
            expect(disk.partition_table.sid).to_not eq ptable_sid
          end

          it "returns :finish" do
            expect(action.run).to eq :finish
          end
        end
      end
    end

    context "for a disk that is part of a RAID" do
      let(:scenario) { "mixed_disks_btrfs.yml" }
      let(:disk_name) { "/dev/sdc" }
      let(:new_md) { Y2Storage::Md.create(current_graph, "/dev/md0") }

      before do
        disk.remove_descendants
        new_md.add_device(disk)

        allow(dialog_class).to receive(:new).and_return dialog
      end

      let(:dialog) { dialog_class.new(disk, [type_gpt, type_msdos], type_gpt) }

      it "shows a confirmation dialog" do
        expect(action).to receive(:confirm_recursive_delete).with(disk, any_args)
        action.run
      end

      context "if the user rejects the confirmation" do
        let(:confirmed) { false }

        it "leaves the disk untouched" do
          action.run
          expect(disk.partition_table?).to eq false
          expect(disk.md).to eq new_md
        end

        it "returns :back" do
          expect(action.run).to eq :back
        end
      end

      context "if the user confirms" do
        let(:confirmed) { true }

        before do
          allow(dialog_class).to receive(:new).and_return dialog
        end
        let(:dialog) { dialog_class.new(disk, [type_gpt, type_msdos], type_gpt) }

        it "displays a dialog to select the partition table type" do
          expect(dialog_class).to receive(:new).with(disk, [type_gpt, type_msdos], type_gpt)
          expect(dialog).to receive(:run)
          action.run
        end

        context "if the user goes back in the type selection" do
          before { allow(dialog).to receive(:run).and_return :back }

          it "leaves the disk untouched" do
            action.run
            expect(disk.partition_table?).to eq false
            expect(disk.md).to eq new_md
          end

          it "returns :finish" do
            expect(action.run).to eq :finish
          end
        end

        context "if the user selects a type" do
          before do
            allow(dialog).to receive(:run).and_return :next
            allow(dialog).to receive(:selected_type).and_return type_gpt
          end

          it "deletes the MD RAID" do
            action.run
            expect(disk.md).to be_nil
          end

          it "adds a new partition table to the disk" do
            action.run
            expect(disk.partition_table.type).to eq type_gpt
          end

          it "returns :finish" do
            expect(action.run).to eq :finish
          end
        end
      end
    end

    context "for a directly formatted device" do
      let(:scenario) { "multipath-formatted.xml" }
      let(:disk_name) { "/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1" }

      before do
        allow(Yast2::Popup).to receive(:show).and_return popup_result
        allow(dialog_class).to receive(:new).and_return dialog
      end

      let(:popup_result) { :no }
      let(:dialog) { dialog_class.new(disk, [type_gpt, type_msdos], type_gpt) }

      it "shows a confirmation dialog regarding data on the filesystem" do
        expect(Yast2::Popup).to receive(:show).with(/Ext4/i, buttons: :yes_no)
        action.run
      end

      context "if the user rejects the confirmation" do
        let(:popup_result) { :no }

        it "leaves the device untouched" do
          fs_id = disk.filesystem.sid
          action.run
          expect(disk.partition_table?).to eq false
          expect(disk.filesystem.sid).to eq fs_id
        end

        it "returns :back" do
          expect(action.run).to eq :back
        end
      end

      context "if the user confirms and selects a type" do
        let(:popup_result) { :yes }

        before do
          allow(dialog).to receive(:run).and_return :next
          allow(dialog).to receive(:selected_type).and_return type_gpt
        end

        it "deletes the filesystem" do
          action.run
          expect(disk.filesystem).to be_nil
        end

        it "adds a new partition table to the disk" do
          action.run
          expect(disk.partition_table.type).to eq type_gpt
        end

        it "returns :finish" do
          expect(action.run).to eq :finish
        end
      end
    end

    context "for an unformatted ECKD DASD (it cannot have partition table)" do
      let(:scenario) { "unformatted-eckd-dasd" }
      let(:disk_name) { "/dev/dasda" }

      before { allow(Yast::Popup).to receive(:Error) }

      it "does not display any confirmation dialog" do
        expect(action).to_not receive(:confirm_recursive_delete)
        action.run
      end

      it "does not display any dialog to select the partition table type" do
        expect(dialog_class).to_not receive(:new)
        action.run
      end

      it "displays an error popup" do
        expect(Yast::Popup).to receive(:Error)
        action.run
      end

      it "returns :back" do
        expect(action.run).to eq :back
      end
    end
  end
end
