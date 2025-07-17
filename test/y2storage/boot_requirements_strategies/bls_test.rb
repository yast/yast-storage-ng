# Copyright (c) [2025] SUSE LLC
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

describe Y2Storage::BootRequirementsStrategies::BLS do
  subject { described_class }

  describe ".bls_bootloader_proposed?" do
    describe "checking suggested bootloader" do
      before do
        allow_any_instance_of(Y2Storage::Arch).to receive(:efiboot?).and_return(true)
        allow(Yast::Arch).to receive(:x86_64).and_return(true)
        allow(Yast::Arch).to receive(:aarch64).and_return(true)
        allow(Y2Storage::StorageEnv.instance).to receive(:no_bls_bootloader).and_return(false)
      end

      context "when a none bls bootloader is suggested" do
        before do
          allow(Yast::ProductFeatures).to receive(:GetStringFeature).with("globals",
            "preferred_bootloader").and_return("grub2-efi")
        end
        it "returns false" do
          expect(subject.bls_bootloader_proposed?).to eq false
        end
      end

      context "when a bls bootloader is suggested" do
        before do
          allow(Yast::ProductFeatures).to receive(:GetStringFeature).with("globals",
            "preferred_bootloader").and_return("systemd-boot")
        end
        it "returns true" do
          expect(subject.bls_bootloader_proposed?).to eq true
        end
      end
    end

    describe "checking architecture" do
      before do
        allow_any_instance_of(Y2Storage::Arch).to receive(:efiboot?).and_return(true)
        allow(Y2Storage::StorageEnv.instance).to receive(:no_bls_bootloader).and_return(false)
        allow(Yast::ProductFeatures).to receive(:GetStringFeature).with("globals",
          "preferred_bootloader").and_return("grub2-bls")
      end

      context "when architectue is not x86_64/aarch64" do
        before do
          allow(Yast::Arch).to receive(:x86_64).and_return(false)
          allow(Yast::Arch).to receive(:aarch64).and_return(false)
        end
        it "returns false" do
          expect(subject.bls_bootloader_proposed?).to eq false
        end
      end

      context "when architectue is x86_64" do
        before do
          allow(Yast::Arch).to receive(:x86_64).and_return(false)
        end
        it "returns true" do
          expect(subject.bls_bootloader_proposed?).to eq true
        end
      end
    end

    describe "checking EFI system" do
      before do
        allow_any_instance_of(Y2Storage::Arch).to receive(:efiboot?).and_return(true)
        allow(Yast::Arch).to receive(:aarch64).and_return(true)
        allow(Y2Storage::StorageEnv.instance).to receive(:no_bls_bootloader).and_return(false)
        allow(Yast::ProductFeatures).to receive(:GetStringFeature).with("globals",
          "preferred_bootloader").and_return("systemd-boot")
      end

      context "when not EFI system" do
        before do
          allow_any_instance_of(Y2Storage::Arch).to receive(:efiboot?).and_return(false)
        end
        it "returns false" do
          expect(subject.bls_bootloader_proposed?).to eq false
        end
      end

      context "when EFI system" do
        before do
          allow_any_instance_of(Y2Storage::Arch).to receive(:efiboot?).and_return(true)
        end
        it "returns true" do
          expect(subject.bls_bootloader_proposed?).to eq true
        end
      end
    end
  end
end
