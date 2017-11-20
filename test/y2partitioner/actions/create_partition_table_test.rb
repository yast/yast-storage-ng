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

    subject { described_class.new(disk_name) }
    let(:disk_name) { "/dev/sdb" }

    describe "#run" do
      it "Runs the correct workflow with type selection and confirmation" do
        expect(select_dialog).to receive(:run).and_return :next
        expect(Yast::Popup).to receive(:YesNo).and_return true
        expect(subject.controller).to receive(:create_partition_table)
        subject.run
      end

      it "Runs the workflow, but does not delete data if not confirmed" do
        expect(select_dialog).to receive(:run).and_return :next
        expect(Yast::Popup).to receive(:YesNo).and_return false
        expect(subject.controller).not_to receive(:create_partition_table)
        subject.run
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

    subject { described_class.new(disk_name) }
    let(:disk_name) { "/dev/sda" }

    describe "#run" do
      it "Runs the correct workflow with no type selection, but confirmation" do
        expect(select_dialog).not_to receive(:run)
        expect(Yast::Popup).to receive(:YesNo).and_return true
        expect(subject.controller).to receive(:create_partition_table)
        subject.run
      end

      it "Runs the workflow, but does not delete data if not confirmed" do
        expect(select_dialog).not_to receive(:run)
        expect(Yast::Popup).to receive(:YesNo).and_return false
        expect(subject.controller).not_to receive(:create_partition_table)
        subject.run
      end
    end
  end
end
