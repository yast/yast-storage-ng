#!/usr/bin/env rspec
# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/actions/add_btrfs"

describe Y2Partitioner::Actions::AddBtrfs do
  before do
    allow(Yast::Popup).to receive(:Error)
    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)

    devicegraph_stub(devicegraph)
  end

  subject(:sequence) { described_class.new }
  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show)
    end

    context "when there are not enough available devices" do
      let(:devicegraph) { "formatted_md.yml" }

      it "shows an error" do
        expect(Yast2::Popup).to receive(:show).with(anything, hash_including(headline: :error))

        sequence.run
      end

      it "quits returning :back" do
        expect(sequence.run).to eq :back
      end
    end

    context "when there are enough available devices" do
      let(:devicegraph) { "complex-lvm-encrypt.yml" }

      context "if the user goes forward through all the dialogs" do
        let(:controller) { Y2Partitioner::Actions::Controllers::BtrfsDevices.new }

        before do
          allow(Y2Partitioner::Actions::Controllers::Filesystem).to receive(:new)
          allow_any_instance_of(Y2Partitioner::Actions::Controllers::BtrfsDevices).to receive(:new)
            .and_return(controller)
          allow(Y2Partitioner::Dialogs::BtrfsDevices).to receive(:run).and_return :next
          allow(Y2Partitioner::Dialogs::BtrfsOptions).to receive(:run).and_return :next
        end

        it "returns :finish" do
          expect(sequence.run).to eq :finish
        end

        it "creates a new Btrfs filesytem" do
          expect(current_graph.btrfs_filesystems.size).to eq 0

          device = current_graph.find_by_name("/dev/sda3")
          controller.add_device(device)
          sequence.run

          expect(current_graph.btrfs_filesystems.size).to eq 1
        end
      end

      context "if the user aborts the process at some point" do
        before do
          allow(Y2Partitioner::Actions::Controllers::Filesystem).to receive(:new)
          allow(Y2Partitioner::Dialogs::BtrfsDevices).to receive(:run).and_return :next
          allow(Y2Partitioner::Dialogs::BtrfsOptions).to receive(:run).and_return :abort
        end

        it "returns :abort" do
          expect(sequence.run).to eq :abort
        end

        it "does not create a new Btrfs filesystem in the devicegraph" do
          expect { sequence.run }.to_not(change { current_graph.btrfs_filesystems })
        end
      end
    end
  end
end
