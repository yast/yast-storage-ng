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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/actions/delete_bcache"

describe Y2Partitioner::Actions::DeleteBcache do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(device) }

  let(:architecture) { :x86_64 } # bcache is only supported on x86_64

  let(:scenario) { "bcache1.xml" }

  let(:device) { Y2Storage::BlkDevice.find_by_name(device_graph, device_name) }

  let(:device_name) { "/dev/bcache1" }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show).and_return(accept)
    end

    let(:accept) { nil }

    context "when deleting probed bcache which share cache with other bcache" do
      let(:device_name) { "/dev/bcache1" }

      it "shows error popup" do
        expect(Yast2::Popup).to receive(:show).with(anything, headline: :error)
        subject.run
      end

      it "does not delete the bcache" do
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
      end

      it "returns :back" do
        expect(subject.run).to eq :back
      end
    end

    context "when deleting a bcache without associated devices" do
      let(:device_name) { "/dev/bcache1" }

      it "shows a confirm message" do
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache2"))
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache0"))
        expect(Yast2::Popup).to receive(:show)
        subject.run
      end

      it "adds note that also cset will be deleted if the bcache is only user of it" do
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache2"))
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache0"))

        expect(Yast2::Popup).to receive(:show).with(/only one using its caching set/, anything)
        subject.run
      end
    end

    context "when deleting a bcache with associated devices" do
      let(:device_name) { "/dev/bcache2" }

      it "shows a specific confirm message for recursive delete" do
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache1"))
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache0"))
        expect(subject).to receive(:confirm_recursive_delete)
          .and_call_original

        subject.run
      end
    end

    context "when the confirm message is not accepted" do
      let(:accept) { :no }

      it "does not delete the bcache" do
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache2"))
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache0"))
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to_not be_nil
      end

      it "returns :back" do
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache2"))
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache0"))
        expect(subject.run).to eq(:back)
      end
    end

    context "when the confirm message is accepted" do
      let(:accept) { :yes }

      it "deletes the bcache" do
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache2"))
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache0"))
        subject.run
        expect(Y2Storage::BlkDevice.find_by_name(device_graph, device_name)).to be_nil
      end

      it "returns :finish" do
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache2"))
        device_graph.remove_bcache(Y2Storage::BlkDevice.find_by_name(device_graph, "/dev/bcache0"))
        expect(subject.run).to eq(:finish)
      end
    end
  end
end
