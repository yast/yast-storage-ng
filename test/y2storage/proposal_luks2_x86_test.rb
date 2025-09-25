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

    subject(:proposal) { described_class.new(settings: settings) }
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

    RSpec.shared_examples "proposes /boot" do
      it "does propose a separate /boot partition" do
        proposal.propose
        boot_fs = proposal.devices.filesystems.find { |fs| fs.mount_path == "/boot" }
        expect(boot_fs.encrypted?).to eq false
      end
    end

    RSpec.shared_examples "not proposes /boot" do
      it "does not propose a separate /boot partition" do
        proposal.propose
        boot_fs = proposal.devices.filesystems.find { |fs| fs.mount_path == "/boot" }
        expect(boot_fs).to be_nil
      end
    end

    RSpec.shared_examples "correct Argon2id encrypted partitions" do
      it "proposes LUKS2 encrypted partitions with Argon2 for all system partitions" do
        proposal.propose
        expect_luks2_fs("/", Y2Storage::PbkdFunction::ARGON2ID)
        expect_luks2_fs("swap", Y2Storage::PbkdFunction::ARGON2ID)
      end
    end

    RSpec.shared_examples "correct PBKDF2 encrypted partitions" do
      it "proposes LUKS2 encrypted partitions with PBKDF2 for all system partitions" do
        proposal.propose
        expect_luks2_fs("/", Y2Storage::PbkdFunction::PBKDF2)
        expect_luks2_fs("swap", Y2Storage::PbkdFunction::PBKDF2)
      end
    end

    RSpec.shared_examples "correct Argon2id encrypted LVM" do
      it "proposes LUKS2 encrypted LVM with Argon2 for all system volumes" do
        proposal.propose
        expect_luks2_lvm_fs("/", Y2Storage::PbkdFunction::ARGON2ID)
        expect_luks2_lvm_fs("swap", Y2Storage::PbkdFunction::ARGON2ID)
      end
    end

    RSpec.shared_examples "correct PBKDF2 encrypted LVM" do
      it "proposes LUKS2 encrypted LVM with PBKDF2 for all system volumes" do
        proposal.propose
        expect_luks2_lvm_fs("/", Y2Storage::PbkdFunction::PBKDF2)
        expect_luks2_lvm_fs("swap", Y2Storage::PbkdFunction::PBKDF2)
      end
    end

    context "In a UEFI system" do
      let(:efi) { true }

      context "proposing LVM" do
        let(:lvm) { true }

        context "default ARGON2ID" do
          let(:pbkdf) { Y2Storage::PbkdFunction::ARGON2ID }
          # FIXME: commented out because the combination of LVM + LUKS2 with Argon2 doesn't work yet
          # include_examples "proposes /boot"
          include_examples "correct Argon2id encrypted LVM"
        end
        context "default PBKDF2" do
          let(:pbkdf) { Y2Storage::PbkdFunction::PBKDF2 }
          include_examples "correct PBKDF2 encrypted LVM"
          include_examples "not proposes /boot"
        end
      end

      context "proposing partitions (no LVM)" do
        let(:lvm) { false }

        context "default ARGON2ID" do
          let(:pbkdf) { Y2Storage::PbkdFunction::ARGON2ID }
          include_examples "correct Argon2id encrypted partitions"
          include_examples "proposes /boot"
        end
        context "default PBKDF2" do
          let(:pbkdf) { Y2Storage::PbkdFunction::PBKDF2 }
          include_examples "correct PBKDF2 encrypted partitions"
          include_examples "not proposes /boot"
        end
      end
    end

    context "In a legacy BIOS boot system" do
      let(:efi) { false }

      context "proposing LVM" do
        let(:lvm) { true }

        context "default ARGON2ID" do
          let(:pbkdf) { Y2Storage::PbkdFunction::ARGON2ID }
          # proposes PBKDF2 although ARGON2ID has been set in the
          # control.xml file because grub2 in a none EFI system can
          # only handle PBKDF2 (bnc#1249670).
          include_examples "correct PBKDF2 encrypted LVM"
          include_examples "not proposes /boot"
        end
        context "default PBKDF2" do
          let(:pbkdf) { Y2Storage::PbkdFunction::PBKDF2 }
          include_examples "correct PBKDF2 encrypted LVM"
          include_examples "not proposes /boot"
        end
      end

      context "proposing partitions (no LVM)" do
        let(:lvm) { false }

        context "default ARGON2ID" do
          # proposes PBKDF2 although ARGON2ID has been set in the
          # control.xml file because grub2 in a none EFI system can
          # only handle PBKDF2 (bnc#1249670).
          let(:pbkdf) { Y2Storage::PbkdFunction::ARGON2ID }
          include_examples "correct PBKDF2 encrypted partitions"
          include_examples "not proposes /boot"
        end
        context "default PBKDF2" do
          let(:pbkdf) { Y2Storage::PbkdFunction::PBKDF2 }
          include_examples "correct PBKDF2 encrypted partitions"
          include_examples "not proposes /boot"
        end
      end
    end
  end
end
