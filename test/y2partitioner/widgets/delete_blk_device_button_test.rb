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
require "y2partitioner/widgets/delete_blk_device_button"

describe Y2Partitioner::Widgets::DeleteBlkDeviceButton do
  subject { described_class.new(table: table) }

  let(:table) do
    instance_double(Y2Partitioner::Widgets::ConfigurableBlkDevicesTable,
      selected_device: device)
  end

  let(:device) { nil }

  include_examples "CWM::PushButton"

  describe "#handle" do
    context "when no device is selected" do
      let(:device) { nil }

      it "shows an error message" do
        expect(Yast::Popup).to receive(:Error)
        subject.handle
      end

      it "returns nil" do
        expect(subject.handle).to be(nil)
      end
    end

    context "when a device is selected" do
      let(:device) { double("Partition") }

      before do
        allow(Y2Partitioner::Actions::DeleteBlkDevice).to receive(:new).with(device)
          .and_return(action)
      end

      let(:action) { instance_double(Y2Partitioner::Actions::DeleteBlkDevice) }

      it "performs the action for deleting the device" do
        expect(action).to receive(:run)
        subject.handle
      end

      it "returns :redraw if the delete action returns :finish" do
        allow(action).to receive(:run).and_return(:finish)
        expect(subject.handle).to eq(:redraw)
      end

      it "returns nil if the delete action does not return :finish" do
        allow(action).to receive(:run).and_return(:back)
        expect(subject.handle).to be_nil
      end
    end
  end
end
