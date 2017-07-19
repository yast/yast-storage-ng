#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

describe Y2Storage::Planned::CanBeEncrypted do

  # Dummy class to test the mixin
  class EncryptableDevice < Y2Storage::Planned::Device
    include Y2Storage::Planned::CanBeEncrypted

    def initialize(password)
      initialize_can_be_encrypted
      self.encryption_password = password
    end
  end

  describe "#final_device!" do
    let(:planned) { EncryptableDevice.new(password) }
    # TODO: test also #encrypted? => true
    let(:plain_device) { instance_double("Y2Storage::BlkDevice", basename: "sda1", encrypted?: false) }
    let(:luks) { instance_double("Storage::Encryption") }

    context "if the planned device has not encryption password" do
      let(:password) { nil }

      it "returns the plain device" do
        device = planned.final_device!(plain_device)
        expect(device).to eq(plain_device)
      end

      it "does not encrypt the device" do
        expect(plain_device).not_to receive(:create_encryption)
        planned.final_device!(plain_device)
      end
    end

    context "if volume has encryption password" do
      let(:password) { "12345678" }

      before do
        allow(plain_device).to receive(:create_encryption).and_return(luks)
        allow(luks).to receive(:password=)
      end

      it "encrypts the device" do
        expect(plain_device).to receive(:create_encryption)
        planned.final_device!(plain_device)
      end

      it "generates encrypted device name based on the plain device name" do
        expect(plain_device).to receive(:create_encryption).with("cr_sda1")
        planned.final_device!(plain_device)
      end

      it "sets the right password to the encrypted device" do
        expect(luks).to receive(:password=).with(password)
        planned.final_device!(plain_device)
      end
    end
  end
end
