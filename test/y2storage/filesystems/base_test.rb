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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::Filesystems::Base do

  before do
    fake_scenario(scenario)
  end
  let(:scenario) { "mixed_disks_btrfs" }
  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, "/dev/sda2") }
  subject(:filesystem) { blk_device.blk_filesystem }

  describe "#free_space" do
    context "#detect_space_info succeed" do
      it "return #detect_space_info#free" do
        fake_space = double(free: Y2Storage::DiskSize.MiB(5))
        allow(filesystem).to receive(:detect_space_info).and_return(fake_space)

        expect(filesystem.free_space).to eq Y2Storage::DiskSize.MiB(5)
      end
    end

    context "#detect_space_info failed" do
      before do
        allow(filesystem).to receive(:detect_space_info).and_raise(Storage::Exception, "error")
      end

      context "it is on block devices" do
        context "detect_resize_info succeed" do
          it "returns size minus minimum resize size" do
            size = Y2Storage::DiskSize.MiB(10)
            allow(filesystem).to receive(:detect_resize_info).and_return(double(min_size: size))

            expect(filesystem.free_space).to eq(blk_device.size - size)
          end
        end

        context "detect_resize_info failed" do
          it "returns zero" do
            allow(filesystem).to receive(:detect_resize_info).and_raise(Storage::Exception, "Error")

            expect(filesystem.free_space).to be_zero
          end
        end
      end

      context "it is not on block device" do
        let(:scenario) { "nfs1.xml" }
        subject(:filesystem) { fake_devicegraph.filesystems.find { |f| f.mount_path == "/test1" } }

        it "returns zero" do

          expect(filesystem.free_space).to be_zero
        end
      end
    end
  end
end
