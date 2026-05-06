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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::EncryptionMethod::TpmBls do
  describe "#initialize" do
    it "sets the correct encryption method id" do
      expect(subject.id).to eq(:tpm_bls)
    end

    it "sets a descriptive name" do
      expect(subject.to_human_string).to match(/BLS.*TPM/i)
    end
  end

  describe ".used_for?" do
    let(:encryption) { instance_double(Y2Storage::Encryption) }

    it "returns false" do
      expect(subject.used_for?(encryption)).to eq(false)
    end
  end

  describe ".only_for_swap?" do
    it "returns false" do
      expect(subject.only_for_swap?).to eq(false)
    end
  end

  describe "#password_required?" do
    it "returns true" do
      expect(subject.password_required?).to eq(true)
    end
  end

  describe "#possible?" do
    before do
      Y2Storage::StorageManager.create_test_instance

      allow(Yast::Arch).to receive(:has_tpm2).and_return(tpm_present)
      allow(Y2Storage::Arch).to receive(:new).and_return(arch)
    end

    let(:arch) { instance_double(Y2Storage::Arch, efiboot?: efi) }

    context "when the system boots using EFI and has TPM2" do
      let(:efi) { true }
      let(:tpm_present) { true }

      it "returns true" do
        expect(subject.possible?).to eq(true)
      end
    end

    context "when the system boots using EFI but has no TPM2" do
      let(:efi) { true }
      let(:tpm_present) { false }

      it "returns false" do
        expect(subject.possible?).to eq(false)
      end
    end

    context "when the system has TPM2 but does not use EFI" do
      let(:efi) { false }
      let(:tpm_present) { true }

      it "returns false" do
        expect(subject.possible?).to eq(false)
      end
    end

    context "when the system does not use EFI and has no TPM2" do
      let(:efi) { false }
      let(:tpm_present) { false }

      it "returns false" do
        expect(subject.possible?).to eq(false)
      end
    end
  end

  describe "#available?" do
    it "returns false" do
      expect(subject.available?).to eq(false)
    end
  end

  describe "#create_device" do
    before do
      Y2Storage::StorageManager.create_test_instance

      allow(Y2Storage::EncryptionProcesses::Sdboot).to receive(:new)
        .with(subject)
        .and_return(encryption_process)
    end

    let(:blk_device) { instance_double(Y2Storage::BlkDevice) }
    let(:dm_name) { "cr_test" }
    let(:encryption_process) { instance_double(Y2Storage::EncryptionProcesses::Sdboot) }
    let(:encrypted_device) { instance_double(Y2Storage::Encryption) }

    it "delegates to the encryption process" do
      expect(encryption_process).to receive(:create_device)
        .with(blk_device, dm_name, hash_including(pbkdf: nil, label: ""))
        .and_return(encrypted_device)

      result = subject.create_device(blk_device, dm_name)
      expect(result).to eq(encrypted_device)
    end

    it "passes pbkdf parameter to the encryption process" do
      pbkdf = instance_double(Y2Storage::PbkdFunction)

      expect(encryption_process).to receive(:create_device)
        .with(blk_device, dm_name, hash_including(pbkdf: pbkdf, label: ""))
        .and_return(encrypted_device)

      subject.create_device(blk_device, dm_name, pbkdf: pbkdf)
    end

    it "passes label parameter to the encryption process" do
      label = "test_label"

      expect(encryption_process).to receive(:create_device)
        .with(blk_device, dm_name, hash_including(pbkdf: nil, label: label))
        .and_return(encrypted_device)

      subject.create_device(blk_device, dm_name, label: label)
    end
  end
end
