# frozen_string_literal: true

# Copyright (c) [2026] SUSE LLC
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
require "yast2/execute"

describe "TPM BLS encryption" do
  let(:manager) { Y2Storage::StorageManager.instance }
  let(:tpm_bls) { Y2Storage::EncryptionMethod::TPM_BLS }

  before { fake_scenario("mixed_disks") }

  describe "Y2Storage::BlkDevice#encrypt" do
    let(:blk_device) { manager.staging.find_by_name("/dev/sda1") }

    it "creates an encryption device with type LUKS2 and method TPM BLS" do
      enc = blk_device.encrypt(method: tpm_bls)
      expect(enc.type.is?(:luks2)).to eq(true)
      expect(enc.method.is?(:tpm_bls)).to eq(true)
    end
  end

  describe "finish installation" do
    before do
      allow(Yast::Execute).to receive(:on_target!)

      sda1 = manager.staging.find_by_name("/dev/sda1")
      sda2 = manager.staging.find_by_name("/dev/sda2")
      sda1.encrypt(method: tpm_bls, password: "notsecret-sda1")
      sda2.encrypt(method: tpm_bls, password: "notsecret-sda2")
    end

    it "adds password used by systemd-cryptenroll" do
      expect(Yast::Execute)
        .to(receive(:on_target!))
        .with("keyctl", "padd", "user", "cryptenroll", "@s",
          hash_including(stdin: "notsecret-sda1"))

      expect(Yast::Execute)
        .to(receive(:on_target!))
        .with("keyctl", "padd", "user", "cryptenroll", "@s",
          hash_including(stdin: "notsecret-sda2"))

      manager.staging.finish_installation
    end

    it "adds password used by sdbootutil" do
      expect(Yast::Execute)
        .to(receive(:on_target!))
        .with("keyctl", "padd", "user", "sdbootutil", "@s",
          hash_including(stdin: "notsecret-sda1"))

      expect(Yast::Execute)
        .to(receive(:on_target!))
        .with("keyctl", "padd", "user", "sdbootutil", "@s",
          hash_including(stdin: "notsecret-sda2"))

      manager.staging.finish_installation
    end

    it "enrolls authentication" do
      expect(Yast::Execute)
        .to(receive(:on_target!))
        .with(/sdbootutil/, "enroll", "--method=tpm2", "--devices=/dev/sda1")

      expect(Yast::Execute)
        .to(receive(:on_target!))
        .with(/sdbootutil/, "enroll", "--method=tpm2", "--devices=/dev/sda2")

      manager.staging.finish_installation
    end
  end
end
