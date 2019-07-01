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
  RSpec.shared_examples "needs no volume" do
    it "does not require any particular volume" do
      expect(checker.needed_partitions).to be_empty
    end
  end

  RSpec.shared_examples "needs /boot partition" do
    it "requires a new /boot partition to install Grub into it" do
      expect(checker.needed_partitions).to contain_exactly(
        an_object_having_attributes(
          mount_point: "/boot", filesystem_type: Y2Storage::Filesystems::Type::EXT4
        )
      )
    end
  end

  RSpec.shared_examples "needs grub partition" do
    it "requires a new GRUB partition" do
      expect(checker.needed_partitions).to contain_exactly(
        an_object_having_attributes(partition_id: bios_boot_id, reuse_name: nil)
      )
    end
  end

  RSpec.shared_context "BIOS GRUB partition" do
    context "if there is no GRUB partition" do
      let(:grub_partitions) { [] }

      include_examples("needs grub partition")
    end

    context "if there is already a GRUB partition" do
      let(:grub_partitions) { [grub_partition] }

      context "and it is on the boot disk" do
        let(:boot_disk) { dev_sda }

        include_examples("needs no volume")
      end

      context "and it is not on the boot disk" do
        let(:boot_disk) { dev_sdb }

        include_examples("needs grub partition")
      end
    end
  end

  describe "#needed_partitions in a x86 system" do
    using Y2Storage::Refinements::SizeCasts

    include_context "boot requirements"

    let(:architecture) { :x86 }
    let(:grub_partitions) { [] }
    let(:efi_partitions) { [] }
    let(:other_efi_partitions) { [] }
    let(:use_lvm) { false }
    let(:mbr_gap_for_grub?) { false }

    # Just to shorten
    let(:bios_boot_id) { Y2Storage::PartitionId::BIOS_BOOT }

    before do
      allow(storage_arch).to receive(:efiboot?).and_return(efiboot)
      allow(dev_sda).to receive(:mbr_gap_for_grub?).and_return mbr_gap_for_grub?
      allow(dev_sda).to receive(:grub_partitions).and_return grub_partitions
      allow(dev_sda).to receive(:efi_partitions).and_return efi_partitions
      allow(dev_sda).to receive(:partitions).and_return(grub_partitions + efi_partitions)
      allow(dev_sdb).to receive(:efi_partitions).and_return other_efi_partitions
      allow(dev_sdb).to receive(:partitions).and_return(other_efi_partitions)
      allow(grub_partition).to receive(:match_volume?).and_return(true)
    end

    let(:grub_partition) { partition_double("/dev/sda1") }

    context "using UEFI" do
      let(:efiboot) { true }

      include_context "plain UEFI"
    end

    context "not using UEFI (legacy PC)" do
      let(:efiboot) { false }

      context "with GPT partition table" do
        let(:boot_ptable_type) { :gpt }

        context "in a partitions-based proposal" do
          let(:use_lvm) { false }

          include_context "BIOS GRUB partition"
        end

        context "in a LVM-based proposal" do
          let(:use_lvm) { true }

          include_context "BIOS GRUB partition"
        end

        context "in an encrypted proposal" do
          let(:use_lvm) { false }
          let(:use_encryption) { true }

          include_context "BIOS GRUB partition"
        end
      end

      context "with a MS-DOS partition table" do
        let(:grub_partitions) { [] }
        let(:boot_ptable_type) { :msdos }
        let(:boot_fs_can_embed_grub?) { false }

        context "if the MBR gap is big enough to embed Grub" do
          let(:mbr_gap_for_grub?) { true }

          context "in a partitions-based proposal" do
            let(:use_lvm) { false }

            include_examples("needs no volume")
          end

          context "in a LVM-based proposal" do
            let(:use_lvm) { true }

            include_examples("needs no volume")
          end

          context "in an encrypted proposal" do
            let(:use_lvm) { false }
            let(:use_encryption) { true }

            include_examples("needs no volume")
          end
        end

        context "with a MBR gap too small to accommodate Grub" do
          let(:mbr_gap_for_grub?) { false }

          context "in a partitions-based proposal" do
            let(:use_lvm) { false }

            context "if the file-system selected for / can embed grub (ext2/3/4 or btrfs)" do
              let(:embed_grub) { true }

              include_examples "needs no volume"
            end

            context "if the file-system selected for / cannot embed grub (eg. XFS)" do
              let(:embed_grub) { false }

              include_examples "needs /boot partition"
            end
          end

          context "in a LVM-based proposal" do
            let(:use_lvm) { true }

            context "if the file-system selected for / can embed grub (ext2/3/4 or btrfs)" do
              let(:embed_grub) { true }

              include_examples "needs /boot partition"
            end

            context "if the file-system selected for / cannot embed grub (eg. XFS)" do
              let(:embed_grub) { false }

              include_examples "needs /boot partition"
            end
          end

          context "in an encrypted proposal" do
            let(:use_lvm) { false }
            let(:use_encryption) { true }

            context "if the file-system selected for / can embed grub (ext2/3/4 or btrfs)" do
              let(:embed_grub) { true }

              include_examples "needs /boot partition"
            end

            context "if the file-system selected for / cannot embed grub (eg. XFS)" do
              let(:embed_grub) { false }

              include_examples "needs /boot partition"
            end
          end
        end
      end

      context "when proposing a boot partition" do
        let(:boot_part) { find_vol("/boot", checker.needed_partitions(target)) }
        # Default values to ensure proposal of boot
        let(:efiboot) { false }
        let(:use_lvm) { true }
        let(:mbr_gap_for_grub?) { false }

        include_examples "proposed boot partition"
      end

      context "when proposing a new GRUB partition" do
        let(:grub_part) { find_vol(nil, checker.needed_partitions(target)) }
        # Default values to ensure a GRUB partition
        let(:boot_ptable_type) { :gpt }
        let(:efiboot) { false }
        let(:grub_partitions) { [] }

        include_examples "proposed GRUB partition"
      end

      context "when proposing a new EFI partition" do
        let(:efi_part) { find_vol("/boot/efi", checker.needed_partitions(target)) }
        let(:desired_efi_part) { find_vol("/boot/efi", checker.needed_partitions(:desired)) }
        # Default values to ensure proposal of EFI partition
        let(:efiboot) { true }
        let(:efi_partitions) { [] }

        include_examples "proposed EFI partition basics"
        include_examples "flexible size EFI partition"
      end
    end
  end
end
