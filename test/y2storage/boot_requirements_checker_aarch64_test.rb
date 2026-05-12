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

require_relative "spec_helper"
require_relative "#{TEST_PATH}/support/proposed_partitions_examples"
require_relative "#{TEST_PATH}/support/boot_requirements_context"
require_relative "#{TEST_PATH}/support/boot_requirements_uefi"
require_relative "#{TEST_PATH}/support/boot_requirements_bls"
require "y2storage"

describe Y2Storage::BootRequirementsChecker do
  describe "#needed_partitions in an aarch64 system" do
    using Y2Storage::Refinements::SizeCasts

    include_context "boot requirements"

    let(:architecture) { :aarch64 }
    let(:efi_partitions) { [] }
    let(:other_efi_partitions) { [] }
    let(:use_lvm) { false }

    # it's always UEFI
    let(:efiboot) { true }

    before do
      allow(storage_arch).to receive(:efiboot?).and_return(efiboot)
      allow(dev_sda).to receive(:efi_partitions).and_return efi_partitions
      allow(dev_sda).to receive(:partitions).and_return(efi_partitions)
      allow(dev_sdb).to receive(:efi_partitions).and_return other_efi_partitions
      allow(dev_sdb).to receive(:partitions).and_return(other_efi_partitions)
    end

    context "when the Grub2 bootloader is going to be installed" do
      let(:bootloader) { Y2Storage::BootloaderType::GRUB2 }

      include_context "plain UEFI"
      include_context "plain UEFI with LUKS2"
    end

    context "when a BLS bootloader is going to be installed by YaST" do
      let(:bootloader) { Y2Storage::BootloaderType::BLS_LEGACY }

      include_context "plain UEFI"
    end

    context "when a BLS bootloader is going to be installed by Agama" do
      let(:bootloader) { Y2Storage::BootloaderType::SYSTEMD_BOOT }

      include_context "BLS scenarios"
    end

    context "when proposing a new EFI partition for the Grub2 bootloader" do
      let(:bootloader) { Y2Storage::BootloaderType::GRUB2 }
      let(:efi_part) { find_vol("/boot/efi", checker.needed_partitions(target)) }

      include_examples "proposed EFI partition basics"
      include_examples "minimalistic EFI partition"
    end

    context "when proposing a new EFI partition for a BLS bootloader in YaST" do
      let(:bootloader) { Y2Storage::BootloaderType::BLS_LEGACY }
      let(:efi_part) { find_vol("/boot/efi", checker.needed_partitions(target)) }

      include_examples "proposed EFI partition basics"
      include_examples "legacy EFI partition for BLS bootloaders"
    end

    context "when proposing a new EFI partition for a BLS bootloader in Agama" do
      let(:bootloader) { Y2Storage::BootloaderType::SYSTEMD_BOOT }
      let(:efi_part) { find_vol("/boot", checker.needed_partitions(target)) }

      include_examples "proposed BLS EFI partition"
    end

    context "when proposing a new XBOOTLDR partition" do
      let(:bootloader) { Y2Storage::BootloaderType::SYSTEMD_BOOT }
      let(:xbootldr_part) { find_vol("/boot", checker.needed_partitions(target)) }
      # Default values to ensure proposal of XBOOTLDR partition
      let(:efi_partition) { partition_double("/dev/sda1", 128.MiB) }
      let(:efi_partitions) { [efi_partition] }
      before do
        allow(efi_partition).to receive(:match_volume?).and_return(true)
        allow(efi_partition).to receive(:id).and_return(Y2Storage::PartitionId::ESP)
        allow(efi_partition).to receive(:filesystem_mountpoint).and_return(nil)
        allow(efi_partition).to receive(:sid).and_return(42)
        allow(devicegraph).to receive(:find_device).with(42).and_return(efi_partition)
      end

      include_examples "proposed XBOOTLDR partition"
    end
  end
end
