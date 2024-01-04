#!/usr/bin/env rspec
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
    include Y2Storage::Planned::CanBeMounted
    include Y2Storage::Planned::CanBeEncrypted

    def initialize(method = Y2Storage::EncryptionMethod::LUKS1, password = "")
      super()

      initialize_can_be_encrypted
      self.encryption_method = method
      self.encryption_password = password
    end
  end

  describe "#final_device!" do
    let(:planned) { EncryptableDevice.new(method, password) }
    # TODO: test also #encrypted? => true
    let(:plain_device) { instance_double("Y2Storage::BlkDevice", encrypted?: false) }

    context "if the planned device has no encryption method or password" do
      let(:method) { nil }
      let(:password) { nil }

      it "returns the plain device" do
        device = planned.final_device!(plain_device)
        expect(device).to eq(plain_device)
      end

      it "does not encrypt the device" do
        expect(plain_device).not_to receive(:encrypt)
        planned.final_device!(plain_device)
      end
    end

    context "if volume has an encryption method" do
      let(:method) { Y2Storage::EncryptionMethod.find(:luks1) }
      let(:password) { "12345678" }

      it "encrypts the device with the right password and a default name" do
        expect(plain_device).to receive(:encrypt).with(method:, password:)
        planned.final_device!(plain_device)
      end
    end

    context "if volume has an encryption password" do
      let(:method) { nil }
      let(:password) { "12345678" }

      it "encrypts the device with the right password and a default name" do
        expect(plain_device).to receive(:encrypt)
          .with(method: Y2Storage::EncryptionMethod.find(:luks1), password:)
        planned.final_device!(plain_device)
      end
    end
  end

  describe "#support_encryption_method?" do
    let(:planned) { EncryptableDevice.new }

    context "when the encryption method is restricted to swap devices" do
      let(:encryption_method) { Y2Storage::EncryptionMethod.find(:random_swap) }

      context "and the planned device will be a swap device" do
        before { planned.mount_point = "swap" }

        it "returns true" do
          expect(planned.supported_encryption_method?(encryption_method)).to eq(true)
        end
      end

      context "and the planned device will not be a swap device" do
        it "returns false" do
          expect(planned.supported_encryption_method?(encryption_method)).to eq(false)
        end
      end

      context "when the encryption method is not restricted to swap devices" do
        let(:encryption_method) { Y2Storage::EncryptionMethod.find(:luks1) }

        it "returns true" do
          expect(planned.supported_encryption_method?(encryption_method)).to eq(true)
        end
      end
    end
  end
end
