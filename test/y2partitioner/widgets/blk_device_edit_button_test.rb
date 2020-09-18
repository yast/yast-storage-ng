#!/usr/bin/env rspec

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

require "cwm/rspec"
require "y2partitioner/widgets/blk_device_edit_button"

RSpec.shared_examples "run edit action" do
  before do
    allow(Y2Partitioner::Actions::EditBlkDevice).to receive(:new).and_return action
  end

  let(:action) { instance_double(Y2Partitioner::Actions::EditBlkDevice, run: :finish) }

  it "opens the edit workflow for the device" do
    expect(Y2Partitioner::Actions::EditBlkDevice).to receive(:new).with(device)
    button.handle
  end

  it "returns :redraw if the workflow returns :finish" do
    allow(action).to receive(:run).and_return :finish
    expect(button.handle).to eq :redraw
  end

  it "returns nil if the workflow does not return :finish" do
    allow(action).to receive(:run).and_return :back
    expect(button.handle).to be_nil
  end
end

describe Y2Partitioner::Widgets::BlkDeviceEditButton do
  before do
    devicegraph_stub(scenario)
  end

  let(:device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, device_name) }

  let(:pager) { nil }

  let(:scenario) { "mixed_disks.yml" }

  include_examples "CWM::PushButton"

  describe "#handle" do
    subject(:button) { described_class.new(device: device, pager: pager) }

    context "when the device is a partition" do
      let(:scenario) { "mixed_disks.yml" }
      let(:device_name) { "/dev/sda1" }
      include_examples "run edit action"
    end

    context "when the device is a Software RAID" do
      let(:scenario) { "md_raid" }
      let(:device_name) { "/dev/md/md0" }
      include_examples "run edit action"
    end

    context "when the device is a disk" do
      let(:scenario) { "mixed_disks.yml" }
      let(:device_name) { "/dev/sda" }
      include_examples "run edit action"
    end

    context "when the device is a dasd" do
      let(:scenario) { "dasd_50GiB.yml" }
      let(:device_name) { "/dev/dasda" }
      include_examples "run edit action"
    end

    context "when the device is a multipath" do
      let(:scenario) { "empty-dasd-and-multipath.xml" }
      let(:device_name) { "/dev/mapper/36005076305ffc73a00000000000013b4" }
      include_examples "run edit action"
    end

    context "when the device is a DM RAID" do
      let(:scenario) { "empty-dm_raids.xml" }
      let(:device_name) { "/dev/mapper/isw_ddgdcbibhd_test1" }
      include_examples "run edit action"
    end

    context "when the device is a BIOS MD RAID" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }
      let(:device_name) { "/dev/md/b" }
      include_examples "run edit action"
    end

    context "when the device is a LVM LV" do
      let(:scenario) { "lvm-two-vgs" }
      let(:device_name) { "/dev/vg0/lv1" }
      include_examples "run edit action"
    end
  end
end
