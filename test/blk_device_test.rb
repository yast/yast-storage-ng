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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::BlkDevice do
  before do
    fake_scenario("complex-lvm-encrypt")
  end

  subject(:device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, device_name) }

  describe "#plain_device" do
    context "for a non encrypted device" do
      let(:device_name) { "/dev/sda2" }

      it "returns the device itself" do
        expect(device.plain_device).to eq device
      end
    end

    context "for an encrypted device" do
      let(:device_name) { "/dev/sda4" }

      it "returns the device itself" do
        expect(device.plain_device).to eq device
      end
    end

    context "for an encryption device" do
      let(:device_name) { "/dev/mapper/cr_sda4" }

      it "returns the encrypted device" do
        expect(device.plain_device).to_not eq device
        expect(device.plain_device.name).to eq "/dev/sda4"
      end
    end
  end

  describe "#lvm_pv" do
    context "for a device directly used as PV" do
      let(:device_name) { "/dev/sde2" }

      it "returns the LvmPv device" do
        expect(device.lvm_pv).to be_a Y2Storage::LvmPv
        expect(device.lvm_pv.blk_device).to eq device
      end
    end

    context "for a device used as encrypted PV" do
      let(:device_name) { "/dev/sde1" }

      it "returns the LvmPv device" do
        expect(device.lvm_pv).to be_a Y2Storage::LvmPv
        expect(device.lvm_pv.blk_device.is?(:encryption)).to eq true
        expect(device.lvm_pv.blk_device.plain_device).to eq device
      end
    end

    context "for a device that is not part of LVM" do
      let(:device_name) { "/dev/sda1" }

      it "returns nil" do
        expect(device.lvm_pv).to be_nil
      end
    end
  end

  describe "#direct_lvm_pv" do
    context "for a device directly used as PV" do
      let(:device_name) { "/dev/sde2" }

      it "returns the LvmPv device" do
        expect(device.direct_lvm_pv).to be_a Y2Storage::LvmPv
        expect(device.direct_lvm_pv.blk_device).to eq device
      end
    end

    context "for a device used as encrypted PV" do
      let(:device_name) { "/dev/sde1" }

      it "returns nil" do
        expect(device.direct_lvm_pv).to be_nil
      end
    end

    context "for a device that is not part of LVM" do
      let(:device_name) { "/dev/sda1" }

      it "returns nil" do
        expect(device.direct_lvm_pv).to be_nil
      end
    end
  end
end
