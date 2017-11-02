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
require "y2partitioner/actions/add_md"
require "y2partitioner/dialogs/md"
require "y2partitioner/dialogs/partition_role"
require "y2partitioner/dialogs/format_and_mount"

describe Y2Partitioner::Actions::AddMd do
  before do
    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)
  end

  subject(:sequence) { described_class.new }

  describe "#run" do
    context "if there are not enough available partitions" do
      before do
        allow(Yast::Popup).to receive(:Error)
        devicegraph_stub("empty_hard_disk_50GiB.yml")
      end

      it "shows an error" do
        expect(Yast::Popup).to receive(:Error)
        sequence.run
      end

      it "quits returning :back" do
        expect(sequence.run).to eq :back
      end

      it "does not create any Md device in the devicegraph" do
        sequence.run
        mds = Y2Storage::Md.all(Y2Partitioner::DeviceGraphs.instance.current)
        expect(mds.size).to eq 0
      end
    end

    context "if there are enough available partitions" do
      before { devicegraph_stub("complex-lvm-encrypt.yml") }

      context "if the user goes forward through all the dialogs" do
        before do
          allow(Y2Partitioner::Dialogs::Md).to receive(:run).and_return :next
          allow(Y2Partitioner::Dialogs::MdOptions).to receive(:run).and_return :next
          allow(Y2Partitioner::Dialogs::PartitionRole).to receive(:run).and_return :next
          allow(Y2Partitioner::Dialogs::FormatAndMount).to receive(:run).and_return :next
        end

        it "returns :finish" do
          expect(sequence.run).to eq :finish
        end

        it "creates a new Md device" do
          mds = Y2Storage::Md.all(Y2Partitioner::DeviceGraphs.instance.current)
          expect(mds.size).to eq 0

          sequence.run

          mds = Y2Storage::Md.all(Y2Partitioner::DeviceGraphs.instance.current)
          expect(mds.size).to eq 1
        end
      end

      context "if the user aborts the process at some point" do
        before do
          allow(Y2Partitioner::Dialogs::Md).to receive(:run).and_return :next
          allow(Y2Partitioner::Dialogs::MdOptions).to receive(:run).and_return :next
          allow(Y2Partitioner::Dialogs::PartitionRole).to receive(:run).and_return :next
          allow(Y2Partitioner::Dialogs::FormatAndMount).to receive(:run).and_return :abort
        end

        it "returns :abort" do
          expect(sequence.run).to eq :abort
        end

        it "does not create any Md device in the devicegraph" do
          sequence.run
          mds = Y2Storage::Md.all(Y2Partitioner::DeviceGraphs.instance.current)
          expect(mds.size).to eq 0
        end
      end
    end
  end
end
