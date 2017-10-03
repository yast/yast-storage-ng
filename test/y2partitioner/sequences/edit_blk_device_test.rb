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
# find current contact information at www.suse.com.

require_relative "../test_helper"
require "y2partitioner/sequences/filesystem_controller"
require "y2partitioner/sequences/edit_blk_device"

describe Y2Partitioner::Sequences::EditBlkDevice do
  describe "#initialize" do
    before { devicegraph_stub("complex-lvm-encrypt.yml") }

    let(:device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, dev_name) }
    let(:controller_class) { Y2Partitioner::Sequences::FilesystemController }

    context "if working on a partition" do
      let(:dev_name) { "/dev/sda1" }

      it "includes the partition device name in the title passed to the controller" do
        expect(controller_class).to receive(:new).with(device, /dev\/sda1/)
        described_class.new(device)
      end
    end

    context "if working on a logical volume" do
      let(:dev_name) { "/dev/vg0/lv1" }

      it "includes the VG device name and the LV name in the title passed to the controller" do
        expect(controller_class).to receive(:new) do |dev, title|
          expect(dev).to eq device
          expect(title).to include "/dev/vg0"
          expect(title).to include "lv1"
          expect(title).to_not include "/dev/vg0/lv1"
        end
        described_class.new(device)
      end
    end

    context "if working on an MD array" do
      before { Y2Storage::Md.create(fake_devicegraph, "/dev/md0") }

      let(:dev_name) { "/dev/md0" }

      it "includes the RAID device name in the title passed to the controller" do
        expect(controller_class).to receive(:new).with(device, /dev\/md0/)
        described_class.new(device)
      end
    end
  end
end
