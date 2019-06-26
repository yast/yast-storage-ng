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
require "y2partitioner/actions/go_to_device_tab"

describe Y2Partitioner::Actions::GoToDeviceTab do
  subject(:action) { described_class.new(device, pager, "&Partitions") }
  let(:device) { double("Device") }
  let(:pager) { double("Pager", device_page: page) }

  describe "#run" do
    context "for a device that doesn't have its own page" do
      let(:page) { nil }

      it "returns nil" do
        expect(action.run).to be_nil
      end
    end

    context "for a device with its own page" do
      let(:page) { double("Page", label: "Device page") }

      it "returns :finish" do
        expect(action.run).to eq :finish
      end
    end
  end
end
