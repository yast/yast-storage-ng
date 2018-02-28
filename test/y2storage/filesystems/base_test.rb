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

  describe "#space_info" do
    context "#detect_space_info succeed" do
      it "return result of #detect_space_info" do
        fake_space = double
        allow(filesystem).to receive(:detect_space_info).and_return(fake_space)

        expect(filesystem.space_info).to eq fake_space
      end
    end

    context "#detect_space_info failed" do
      before do
        allow(filesystem).to receive(:detect_space_info).and_raise(Storage::Exception, "error")
      end

      context "it is block filesystem" do
        it "returns ManualSpaceInfo with size of blk device" do
          expect(filesystem.space_info.size).to eq blk_device.size
        end

        context "detect_resize_info succeed" do
          it "returns ManualSpaceInfo with used equal to minimal resize" do
            size = Y2Storage::DiskSize.MiB(10)
            allow(filesystem).to receive(:detect_resize_info).and_return(double(min_size: size))

            expect(filesystem.space_info.used).to eq size
          end
        end

        context "detect_resize_info failed" do
          it "returns ManualSpaceInfo with used equal to zero" do
            size = Y2Storage::DiskSize.MiB(0)
            allow(filesystem).to receive(:detect_resize_info).and_raise(Storage::Exception, "Error")

            expect(filesystem.space_info.used).to eq size
          end
        end
      end

      context "it is not block filesystem" do
        it "returns ManualSpaceInfo with size and used equal to zero" do
          allow(filesystem).to receive(:is?).and_return(false)

          size = Y2Storage::DiskSize.MiB(0)
          expect(filesystem.space_info.used).to eq size
          expect(filesystem.space_info.size).to eq size
        end
      end
    end
  end
end
