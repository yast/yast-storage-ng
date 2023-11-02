#!/usr/bin/env rspec
# Copyright (c) [2023] SUSE LLC
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

describe "TPM full-disk encryption" do
  before do
    fake_scenario("mixed_disks")
  end

  let(:manager) { Y2Storage::StorageManager.instance }
  let(:tpm_fde) { Y2Storage::EncryptionMethod::TPM_FDE }

  describe "Y2Storage::BlkDevice#encrypt" do
    let(:blk_device) { manager.staging.find_by_name("/dev/sda2") }

    it "creates an encryption device with type LUKS2 and method TPM_FDE" do
      enc = blk_device.encrypt(method: tpm_fde)
      expect(enc.type.is?(:luks2)).to eq(true)
      expect(enc.method).to eq tpm_fde
    end

    it "initializes the crypttab fields to the appropriate values" do
      enc = blk_device.encrypt(method: tpm_fde)
      expect(enc.crypt_options).to include "x-initrd.attach"
      expect(enc.key_file).to eq "/.fde-virtual.key"
      expect(enc.use_key_file_in_commit?).to eq false
    end
  end

  describe "finish installation" do
    before do
      allow(manager.storage).to receive(:calculate_actiongraph)
      allow(manager.storage).to receive(:commit)

      allow(Yast::Mode).to receive(:installation).and_return true
      allow(Yast::Stage).to receive(:initial).and_return true

      allow(Yast::SCR).to receive(:Write)
      # The code verifies the values were actually written, let's emulate that
      allow(Yast::SCR).to receive(:Read) do |path|
        blk_devices.join(" ") if path.to_s.match?(/fde-tools.FDE_DEVS/)
      end

      expect(Yast2::Systemd::Service).to receive(:find).with("fde-tpm-enroll.service")
        .and_return(enroll_service)

      devices = blk_devices.map { |d| manager.staging.find_by_name(d) }
      devices.each { |d| d.encrypt(method: tpm_fde) }

      allow(Yast::Execute).to receive(:on_target!)
    end

    let(:blk_devices) { ["/dev/sda2", "/dev/sdb2"] }
    let(:enroll_service) { double(Yast2::Systemd::Service, enable: true) }

    it "adds the encrypted block devices to the fde-tools configuration" do
      expect(Yast::SCR).to receive(:Write) do |path, value|
        expect(path.to_s).to match(/fde-tools.FDE_DEVS/)
        expect(value).to eq(blk_devices.join(" "))
      end

      manager.commit
      manager.staging.finish_installation
    end

    it "calls only once the command to add secondary passwords" do
      expect(Yast::Execute).to receive(:on_target!)
        .with(/fdectl/, "add-secondary-password", any_args).once

      manager.commit
      manager.staging.finish_installation
    end

    it "calls only once the command to add secondary keys" do
      expect(Yast::Execute).to receive(:on_target!)
        .with(/fdectl/, "add-secondary-key", any_args).once

      manager.commit
      manager.staging.finish_installation
    end

    it "enables the enroll service" do
      expect(enroll_service).to receive(:enable).and_return true

      manager.commit
      manager.staging.finish_installation
    end
  end
end
