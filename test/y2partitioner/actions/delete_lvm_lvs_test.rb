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
require "y2partitioner/actions/delete_lvm_lvs"

describe Y2Partitioner::Actions::DeleteLvmLvs do
  before { devicegraph_stub("lvm-two-vgs") }
  subject { described_class.new(device) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { device_graph.find_by_name(device_name) }

  describe "#run" do
    before do
      allow(Yast2::Popup).to receive(:show)
    end

    context "when deleting LVs from an already empty volume group" do
      let(:device_name) { "/dev/vg1" }

      before { device.delete_lvm_lv(device.lvm_lvs.first) }

      it "shows an error message" do
        expect(Yast2::Popup).to receive(:show)
          .with(/does not contain/, anything)

        subject.run
      end

      it "returns :back" do
        expect(subject.run).to eq(:back)
      end
    end

    context "when deleting existing LVs from a volume group" do
      let(:device_name) { "/dev/vg0" }

      before do
        allow(subject).to receive(:confirm_recursive_delete).and_return(accept)
      end

      let(:accept) { nil }

      it "shows a confirm message" do
        expect(subject).to receive(:confirm_recursive_delete)

        subject.run
      end

      context "and the confirm message is not accepted" do
        let(:accept) { false }

        it "does not delete the logical volumes" do
          subject.run

          expect(device.lvm_lvs).to_not be_empty
        end

        it "returns :back" do
          expect(subject.run).to eq(:back)
        end
      end

      context "and the confirm message is accepted" do
        let(:accept) { true }

        it "deletes the logical volumes" do
          subject.run

          expect(device.lvm_lvs).to be_empty
        end

        it "refreshes btrfs subvolumes shadowing" do
          expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
          subject.run
        end

        it "returns :finish" do
          expect(subject.run).to eq(:finish)
        end
      end
    end
  end
end
