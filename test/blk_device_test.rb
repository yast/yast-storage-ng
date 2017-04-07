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

  describe "#plain_device" do
    subject(:device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, device_name) }

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
end
