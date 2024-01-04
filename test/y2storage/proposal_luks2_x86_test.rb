#!/usr/bin/env rspec
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
require "storage"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  using Y2Storage::Refinements::SizeCasts

  describe "#propose" do
    include_context "proposal"

    subject(:proposal) { described_class.new(settings:) }
    let(:scenario) { "empty_hard_disk_50GiB" }
    let(:architecture) { :x86 }
    let(:control_file) { "legacy_settings.xml" }
    let(:encrypt) { true }

    before do
      allow(Yast::Kernel).to receive(:propose_hibernation?).and_return(true)
      allow(storage_arch).to receive(:efiboot?).and_return(efi)

      settings.encryption_method = Y2Storage::EncryptionMethod::LUKS2
      settings.encryption_pbkdf = pbkdf
    end

    # Helper method to check the properties of an encrypted filesystem
    def expect_luks2_fs(mount_path, pbkdf)
      fs = proposal.devices.filesystems.find { |i| i.mount_path == mount_path }
      expect(fs.encrypted?).to eq true

      enc = fs.blk_devices.first
      expect(enc.type).to eq Y2Storage::EncryptionType::LUKS2
      expect(enc.pbkdf).to eq pbkdf
    end

    # Helper method to check the properties of a filesystem inside an encrypted LVM
    def expect_luks2_lvm_fs(mount_path, pbkdf)
      fs = proposal.devices.filesystems.find { |i| i.mount_path == mount_path }
      expect(fs.encrypted?).to eq false

      lv = fs.blk_devices.first
      expect(lv.is?(:lvm_lv)).to eq true

      pvs = lv.lvm_vg.lvm_pvs
      encs = pvs.map(&:blk_device)
      expect(encs.map(&:type)).to all(eq Y2Storage::EncryptionType::LUKS2)
      expect(encs.map(&:pbkdf)).to all(eq pbkdf)
    end

    RSpec.shared_examples "/boot unless PBKDF2" do
      context "using Argon2id as key derivation function" do
        let(:pbkdf) { Y2Storage::PbkdFunction::ARGON2ID }

        it "proposes a separate unencrypted /boot partition" do
          proposal.propose
          boot_fs = proposal.devices.filesystems.find { |fs| fs.mount_path == "/boot" }
          expect(boot_fs.encrypted?).to eq false
        end
      end

      context "using PBKDF2 as key derivation function" do
        let(:pbkdf) { Y2Storage::PbkdFunction::PBKDF2 }

        it "does not propose a separate /boot partition" do
          proposal.propose
          boot_fs = proposal.devices.filesystems.find { |fs| fs.mount_path == "/boot" }
          expect(boot_fs).to be_nil
        end
      end
    end

    RSpec.shared_examples "correct PBKDF encrypted partitions" do
      context "using Argon2id as key derivation function" do
        let(:pbkdf) { Y2Storage::PbkdFunction::ARGON2ID }

        it "proposes LUKS2 encrypted partitions with Argon2 for all system partitions" do
          proposal.propose
          expect_luks2_fs("/", Y2Storage::PbkdFunction::ARGON2ID)
          expect_luks2_fs("swap", Y2Storage::PbkdFunction::ARGON2ID)
        end
      end

      context "using PBKDF2 as key derivation function" do
        let(:pbkdf) { Y2Storage::PbkdFunction::PBKDF2 }

        it "proposes LUKS2 encrypted partitions with PBKDF2 for all system partitions" do
          proposal.propose
          expect_luks2_fs("/", Y2Storage::PbkdFunction::PBKDF2)
          expect_luks2_fs("swap", Y2Storage::PbkdFunction::PBKDF2)
        end
      end
    end

    RSpec.shared_examples "correct PBKDF encrypted LVM" do
      context "using Argon2id as key derivation function" do
        let(:pbkdf) { Y2Storage::PbkdFunction::ARGON2ID }

        it "proposes LUKS2 encrypted LVM with Argon2 for all system volumes" do
          proposal.propose
          expect_luks2_lvm_fs("/", Y2Storage::PbkdFunction::ARGON2ID)
          expect_luks2_lvm_fs("swap", Y2Storage::PbkdFunction::ARGON2ID)
        end
      end

      context "using PBKDF2 as key derivation function" do
        let(:pbkdf) { Y2Storage::PbkdFunction::PBKDF2 }

        it "proposes LUKS2 encrypted LVM with PBKDF2 for all system volumes" do
          proposal.propose
          expect_luks2_lvm_fs("/", Y2Storage::PbkdFunction::PBKDF2)
          expect_luks2_lvm_fs("swap", Y2Storage::PbkdFunction::PBKDF2)
        end
      end
    end

    context "In a UEFI system" do
      let(:efi) { true }

      context "proposing LVM" do
        let(:lvm) { true }

        # FIXME: commented out because the combination of LVM + LUKS2 with Argon2 doesn't work yet
        # include_examples "/boot unless PBKDF2"
        include_examples "correct PBKDF encrypted LVM"
      end

      context "proposing partitions (no LVM)" do
        let(:lvm) { false }

        include_examples "/boot unless PBKDF2"
        include_examples "correct PBKDF encrypted partitions"
      end
    end

    context "In a legacy BIOS boot system" do
      let(:efi) { false }

      context "proposing LVM" do
        let(:lvm) { true }

        # FIXME: commented out because the combination of LVM + LUKS2 with Argon2 doesn't work yet
        # include_examples "/boot unless PBKDF2"
        include_examples "correct PBKDF encrypted LVM"
      end

      context "proposing partitions (no LVM)" do
        let(:lvm) { false }

        include_examples "/boot unless PBKDF2"
        include_examples "correct PBKDF encrypted partitions"
      end
    end
  end
end
