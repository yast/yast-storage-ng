#!/usr/bin/env rspec
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

RSpec.shared_context "BLS layout" do
  before do
    allow(analyzer).to receive(:free_mountpoint?).with("/boot").and_return(true)
  end

  context "if there are no EFI partitions" do
    let(:efi_partitions) { [] }

    it "requires only a new EFI partition mounted at /boot" do
      partitions = checker.needed_partitions
      expect(partitions.size).to eq 1
      expect(partitions.first).to have_attributes(
        mount_point:  "/boot",
        partition_id: Y2Storage::PartitionId::ESP,
        reuse_name:   nil
      )
    end
  end

  context "if there is already an EFI partition" do
    let(:efi_partitions) { [efi_partition] }
    let(:efi_partition) { partition_double("/dev/sda1") }

    before do
      allow(efi_partition).to receive(:match_volume?).and_return(match)
      allow(efi_partition).to receive(:id).and_return(Y2Storage::PartitionId::ESP)
      allow(efi_partition).to receive(:filesystem_mountpoint).and_return(nil)
      allow(efi_partition).to receive(:size).and_return(esp_size)
      allow(efi_partition).to receive(:sid).and_return(42)
      allow(devicegraph).to receive(:find_device).with(42).and_return(efi_partition)
    end

    context "and it is not suitable (invalid filesystem)" do
      let(:match) { false }
      let(:esp_size) { Y2Storage::DiskSize.GiB(1) }

      it "requires a new EFI partition mounted at /boot" do
        partitions = checker.needed_partitions
        expect(partitions.size).to eq 1
        expect(partitions.first).to have_attributes(
          mount_point:  "/boot",
          partition_id: Y2Storage::PartitionId::ESP,
          reuse_name:   nil
        )
      end
    end

    context "and it is usable but too small to allocate several kernels" do
      let(:match) { true }
      let(:esp_size) { Y2Storage::DiskSize.MiB(100) }

      it "requires creating a XBOOTLDR partition at /boot" do
        expect(checker.needed_partitions).to include(
          an_object_having_attributes(
            mount_point:  "/boot",
            partition_id: Y2Storage::PartitionId::XBOOTLDR,
            reuse_name:   nil
          )
        )
      end

      it "requires to mount the existing EFI partition at /efi" do
        expect(checker.needed_partitions).to include(
          an_object_having_attributes(mount_point: "/efi", reuse_name: "/dev/sda1")
        )
      end
    end

    context "and it is usable and big enough" do
      let(:match) { true }
      let(:esp_size) { Y2Storage::DiskSize.GiB(1) }

      it "only requires to mount the existing EFI partition at /boot" do
        expect(checker.needed_partitions).to include(
          an_object_having_attributes(mount_point: "/boot", reuse_name: "/dev/sda1")
        )
      end
    end
  end
end

RSpec.shared_context "BLS scenarios" do
  context "with a partitions-based proposal" do
    let(:use_lvm) { false }

    include_context "BLS layout"
  end

  context "with a LVM-based proposal" do
    let(:use_lvm) { true }

    include_context "BLS layout"
  end

  context "with an encrypted proposal" do
    let(:use_lvm) { false }
    let(:use_encryption) { true }

    include_context "BLS layout"
  end
end
