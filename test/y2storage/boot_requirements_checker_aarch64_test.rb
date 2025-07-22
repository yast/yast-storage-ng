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

    include_context "plain UEFI"

    context "when proposing a new EFI partition" do
      let(:efi_part) { find_vol("/boot/efi", checker.needed_partitions(target)) }
      let(:desired_efi_part) { find_vol("/boot/efi", checker.needed_partitions(:desired)) }

      context "and BLS bootloader is explicitly disabled" do
        before do
          allow(Y2Storage::BootRequirementsStrategies::BLS).to receive(
                                                                 :bls_bootloader_proposed?
                                                               ).and_return(false)
        end

        include_examples "minimalistic EFI partition"
      end
    end
  end
end
