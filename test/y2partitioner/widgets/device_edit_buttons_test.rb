#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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
require "y2partitioner/widgets/device_edit_buttons"

shared_context "button context" do
  before do
    devicegraph_stub(scenario)

    allow(action).to receive(:new).with(device).and_return(instance_double(action, run: action_result))
  end

  subject { described_class.new(device: device) }

  let(:action_result) { :finish }

  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
end

shared_examples "modify button" do
  include_context "button context"

  let(:scenario) { "one-empty-disk" }

  let(:device) { devicegraph.find_by_name("/dev/sda") }

  include_examples "CWM::PushButton"

  describe "#handle" do
    context "when no device is given" do
      let(:device) { nil }

      before do
        allow(Yast2::Popup).to receive(:show)
      end

      it "shows an error message" do
        expect(Yast2::Popup).to receive(:show)

        subject.handle
      end

      it "returns nil" do
        expect(subject.handle).to be_nil
      end
    end

    it "starts the proper action to modify the device" do
      expect(action).to receive(:new).with(device)

      subject.handle
    end

    context "if the action returns :finish" do
      let(:action_result) { :finish }

      it "returns :redraw" do
        expect(subject.handle).to eq(:redraw)
      end
    end

    context "if the action does not return :finish" do
      let(:action_result) { nil }

      it "returns nil" do
        expect(subject.handle).to be_nil
      end
    end
  end
end

describe Y2Partitioner::Widgets::BlkDeviceEditButton do
  let(:action) { Y2Partitioner::Actions::EditBlkDevice }

  include_examples "modify button"
end

describe Y2Partitioner::Widgets::BtrfsEditButton do
  let(:action) { Y2Partitioner::Actions::EditBtrfs }

  include_examples "modify button"
end

describe Y2Partitioner::Widgets::BtrfsSubvolumeEditButton do
  let(:action) { Y2Partitioner::Actions::EditBtrfsSubvolume }

  include_examples "modify button"
end

describe Y2Partitioner::Widgets::BcacheEditButton do
  let(:action) { Y2Partitioner::Actions::EditBcache }

  include_examples "modify button"
end

describe Y2Partitioner::Widgets::MdDevicesEditButton do
  let(:action) { Y2Partitioner::Actions::EditMdDevices }

  include_examples "modify button"
end

describe Y2Partitioner::Widgets::BtrfsDevicesEditButton do
  let(:action) { Y2Partitioner::Actions::EditBtrfsDevices }

  include_examples "modify button"
end

describe Y2Partitioner::Widgets::LvmVgResizeButton do
  let(:action) { Y2Partitioner::Actions::ResizeLvmVg }

  include_examples "modify button"
end
