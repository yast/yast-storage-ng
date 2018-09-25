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
# find current contact information at www.suse.com.

require_relative "../test_helper"
require "y2partitioner/device_graphs"
require "y2partitioner/actions/add_bcache"
require "y2partitioner/dialogs/bcache"

describe Y2Partitioner::Actions::AddBcache do
  let(:dialog) do
    Y2Partitioner::Dialogs::Bcache.new(
      fake_devicegraph.blk_devices,
      fake_devicegraph.blk_devices
    )
  end

  let(:selected_backing) { fake_devicegraph.blk_devices.find { |d| d.name == "/dev/sda1" } }
  let(:selected_caching) { fake_devicegraph.blk_devices.find { |d| d.name == "/dev/sdc" } }

  subject { described_class.new }

  before do
    devicegraph_stub("empty_disks.yml")
    my_dialog = dialog
    allow(Y2Partitioner::Dialogs::Bcache).to receive(:new).and_return(my_dialog)
  end

  describe "#run" do
    before do
      allow(dialog).to receive(:run).and_return :next
      allow(dialog).to receive(:backing_device).and_return(selected_backing)
      allow(dialog).to receive(:caching_device).and_return(selected_caching)
    end

    it "returns :finish" do
      expect(subject.run).to eq :finish
    end

    it "creates a new bcache device" do
      bcaches = fake_devicegraph.bcaches
      expect(bcaches.size).to eq 0

      subject.run

      bcaches = fake_devicegraph.bcaches
      expect(bcaches.size).to eq 1
    end
  end
end
