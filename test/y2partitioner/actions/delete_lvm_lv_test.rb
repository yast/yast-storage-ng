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
require "y2partitioner/actions/delete_lvm_lv"

describe Y2Partitioner::Actions::DeleteLvmLv do
  before do
    devicegraph_stub("lvm-two-vgs.yml")
  end

  subject { described_class.new(device) }

  let(:device) { Y2Storage::BlkDevice.find_by_name(device_graph, device_name) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Yast::Popup).to receive(:YesNo).and_return(accept)
    end

    let(:device_name) { "/dev/vg1/lv1" }

    let(:accept) { nil }

    it "shows a confirm message" do
      expect(Yast::Popup).to receive(:YesNo)
      subject.run
    end

    context "when the confirm message is not accepted" do
      let(:accept) { false }

      it "does not delete the logical volume" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when the confirm message is accepted" do
      let(:accept) { true }

      it "deletes the logical volume" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to be_nil
      end

      it "refresh btrfs subvolumes shadowing" do
        expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
        subject.run
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end
    end
  end
end
