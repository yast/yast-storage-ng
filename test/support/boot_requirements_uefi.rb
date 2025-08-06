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

RSpec.shared_context "plain UEFI" do
  RSpec.shared_context "UEFI partition" do
    using Y2Storage::Refinements::SizeCasts

    context "if there are no EFI partitions" do
      let(:efi_partitions) { [] }

      it "requires only a new /boot/efi partition" do
        expect(checker.needed_partitions).to contain_exactly(
          an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil)
        )
      end
    end

    context "if there is already an EFI partition" do
      let(:efi_partitions) { [efi_partition] }

      let(:efi_partition) { partition_double("/dev/sda1") }

      before do
        allow(efi_partition).to receive(:match_volume?).and_return(match)
        allow(efi_partition).to receive(:id).and_return(Y2Storage::PartitionId::ESP)
      end

      context "and it is not a suitable EFI partition (not enough size, invalid filesystem)" do
        let(:match) { false }

        it "requires only a new /boot/efi partition" do
          expect(checker.needed_partitions).to contain_exactly(
            an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil)
          )
        end
      end

      context "and it is a suitable EFI partition (enough size, valid filesystem)" do
        let(:match) { true }

        context "and it is on the boot disk" do
          let(:boot_disk) { dev_sda }

          it "only requires to use the existing EFI partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse_name: "/dev/sda1")
            )
          end
        end

        context "and it is not on the boot disk" do
          let(:boot_disk) { dev_sdb }

          it "requires only a new /boot/efi partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil)
            )
          end
        end
      end
    end
  end

  context "with a partitions-based proposal" do
    let(:use_lvm) { false }

    include_context "UEFI partition"
  end

  context "with a LVM-based proposal" do
    let(:use_lvm) { true }

    include_context "UEFI partition"
  end

  context "with an encrypted proposal" do
    let(:use_lvm) { false }
    let(:use_encryption) { true }

    include_context "UEFI partition"
  end

  # See https://lists.opensuse.org/archives/list/factory@lists.opensuse.org/message/5L6XAYM2JFBP5RJOIFKFM34D3BK7VHWS/
  context "with an AutoYaST profile that places '/' in a LUKS2 device" do
    let(:use_lvm) { false }
    let(:use_encryption) { true }
    let(:boot_enc_type) { Y2Storage::EncryptionType::LUKS2 }

    context "if there are no EFI partitions" do
      let(:efi_partitions) { [] }

      it "requires new partitions for /boot/efi and for /boot (Grub2 auto-config cannot handle LUKS2)" do
        expect(checker.needed_partitions).to contain_exactly(
          an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil),
          an_object_having_attributes(mount_point: "/boot")
        )
      end
    end

    context "if there is already a suitable EFI partition in the boot disk" do
      let(:efi_partitions) { [efi_partition] }
      let(:efi_partition) { partition_double("/dev/sda1") }
      let(:boot_disk) { dev_sda }

      before do
        allow(efi_partition).to receive(:match_volume?).and_return(true)
        allow(efi_partition).to receive(:id).and_return(Y2Storage::PartitionId::ESP)
      end

      it "requires to reuse EFI and create a /boot partition (Grub2 auto-config cannot handle LUKS2)" do
        expect(checker.needed_partitions).to contain_exactly(
          an_object_having_attributes(mount_point: "/boot/efi", reuse_name: "/dev/sda1"),
          an_object_having_attributes(mount_point: "/boot")
        )
      end
    end
  end
end

RSpec.shared_context "BLS bootloader proposed" do
  context "and BLS bootloader is proposed and possible" do
    before do
      allow(Y2Storage::BootRequirementsStrategies::Analyzer).to receive(
                                                                  :bls_bootloader_proposed?
                                                                ).and_return(true)
    end

    include_examples "EFI partition for BLS bootloaders"
  end
end
