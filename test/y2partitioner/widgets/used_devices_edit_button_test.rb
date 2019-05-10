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
require "y2partitioner/widgets/used_devices_edit_button"

describe Y2Partitioner::Widgets::UsedDevicesEditButton do
  subject(:button) { described_class.new(device: device) }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks" }

  let(:device_name) { "/dev/sda" }

  let(:device) { device_graph.find_by_name(device_name) }

  before do
    devicegraph_stub(scenario)
  end

  include_examples "CWM::PushButton"

  describe "#handle" do
    context "when the device is not a Software RAID" do
      it "returns nil" do
        expect(button.handle).to be(nil)
      end
    end

    context "when the device is a Software RAID" do
      let(:scenario) { "formatted_md" }
      let(:device_name) { "/dev/md0" }
      let(:action) { instance_double(Y2Partitioner::Actions::EditMdDevices, run: :finish) }

      before do
        allow(Y2Partitioner::Actions::EditMdDevices).to receive(:new).and_return(action)
      end

      it "calls the action to edit the used devices" do
        expect(Y2Partitioner::Actions::EditMdDevices).to receive(:new).with(device)

        button.handle
      end

      it "returns :redraw if the action was successful" do
        allow(action).to receive(:run).and_return(:finish)

        expect(button.handle).to eq(:redraw)
      end

      it "returns nil if the action was not successful" do
        allow(action).to receive(:run).and_return(:back)

        expect(button.handle).to be_nil
      end
    end

    context "when the device is a Btrfs filesystem" do
      subject(:button) { described_class.new(device: fs) }

      let(:scenario) { "btrfs_on_disk" }
      let(:device_name) { "/dev/sda" }
      let(:fs) { device.filesystem }
      let(:action) { instance_double(Y2Partitioner::Actions::EditBtrfsDevices, run: :finish) }

      before do
        allow(Y2Partitioner::Actions::EditBtrfsDevices).to receive(:new).and_return(action)
      end

      it "calls the action to edit the used devices" do
        expect(Y2Partitioner::Actions::EditBtrfsDevices).to receive(:new).with(fs)

        button.handle
      end

      it "returns :redraw if the action was successful" do
        allow(action).to receive(:run).and_return(:finish)

        expect(button.handle).to eq(:redraw)
      end

      it "returns nil if the action was not successful" do
        allow(action).to receive(:run).and_return(:back)

        expect(button.handle).to be_nil
      end
    end
  end
end
