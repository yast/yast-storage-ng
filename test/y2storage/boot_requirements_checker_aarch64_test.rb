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

require_relative "spec_helper"
require_relative "#{TEST_PATH}/support/proposed_partitions_examples"
require_relative "#{TEST_PATH}/support/boot_requirements_context"
require_relative "#{TEST_PATH}/support/boot_requirements_uefi"
require "y2storage"

describe Y2Storage::BootRequirementsChecker do
  # TODO: make it work
  xdescribe "#needed_partitions in an aarch64 system" do
    using Y2Storage::Refinements::SizeCasts

    include_context "boot requirements"

    let(:architecture) { :aarch64 }
    let(:efi_partitions) { [] }
    let(:other_efi_partitions) { [] }
    let(:use_lvm) { false }
    let(:sda_part_table) { pt_msdos }
    let(:mbr_gap_size) { Y2Storage::DiskSize.zero }

    # it's always UEFI
    let(:efiboot) { true }

    before do
      allow(dev_sda).to receive(:mbr_gap).and_return mbr_gap_size
      allow(dev_sda).to receive(:efi_partitions).and_return efi_partitions
      allow(dev_sda).to receive(:partitions).and_return(efi_partitions)
      allow(dev_sdb).to receive(:efi_partitions).and_return other_efi_partitions
      allow(dev_sdb).to receive(:partitions).and_return(other_efi_partitions)
    end

    include_context "plain UEFI"

  end
end
