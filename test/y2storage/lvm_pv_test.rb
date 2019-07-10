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

describe Y2Storage::LvmPv do
  before do
    fake_scenario("complex-lvm-encrypt")
  end

  describe "#plain_blk_device" do
    subject(:pv) do
      Y2Storage::LvmPv.all(fake_devicegraph).detect { |p| p.blk_device.name == device_name }
    end

    context "for a non encrypted PV" do
      let(:device_name) { "/dev/sde2" }

      it "returns the device directly hosting the PV" do
        expect(pv.plain_blk_device).to eq pv.blk_device
      end
    end

    context "for an encrypted PV" do
      let(:device_name) { "/dev/mapper/cr_sde1" }

      it "returns the plain version of the encrypted device" do
        expect(pv.plain_blk_device).to_not eq pv.blk_device
        expect(pv.plain_blk_device).to eq pv.blk_device.plain_device
      end
    end
  end
end
