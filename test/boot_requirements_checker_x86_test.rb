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
require_relative "support/proposed_partitions_examples"
require_relative "support/boot_requirements_context"
require "y2storage"

describe Y2Storage::BootRequirementsChecker do
  describe "#needed_partitions in a x86 system" do
    using Y2Storage::Refinements::SizeCasts

    include_context "boot requirements"

    let(:architecture) { :x86 }
    let(:grub_partitions) { [] }
    let(:efi_partitions) { [] }
    let(:other_efi_partitions) { [] }
    let(:use_lvm) { false }
    let(:sda_part_table) { pt_msdos }
    let(:mbr_gap_size) { Y2Storage::DiskSize.zero }

    # Just to shorten
    let(:bios_boot_id) { Y2Storage::PartitionId::BIOS_BOOT }

    before do
      allow(storage_arch).to receive(:efiboot?).and_return(efiboot)
      allow(dev_sda).to receive(:mbr_gap).and_return mbr_gap_size
      allow(dev_sda).to receive(:grub_partitions).and_return grub_partitions
      allow(dev_sda).to receive(:efi_partitions).and_return efi_partitions
      allow(dev_sdb).to receive(:efi_partitions).and_return other_efi_partitions
    end

    context "using UEFI" do
      let(:efiboot) { true }

      context "with a partitions-based proposal" do
        let(:use_lvm) { false }

        context "if there are no EFI partitions" do
          let(:efi_partitions) { [] }

          it "requires only a new /boot/efi partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse: nil)
            )
          end
        end

        context "if there is already an EFI partition" do
          let(:efi_partitions) { [partition_double("/dev/sda1")] }

          it "only requires to use the existing EFI partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse: "/dev/sda1")
            )
          end
        end
      end

      context "with a LVM-based proposal" do
        let(:use_lvm) { true }

        context "if there are no EFI partitions" do
          let(:efi_partitions) { [] }

          it "requires only a new /boot/efi partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse: nil)
            )
          end
        end

        context "if there is already an EFI partition" do
          let(:efi_partitions) { [partition_double("/dev/sda1")] }

          it "only requires to use the existing EFI partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse: "/dev/sda1")
            )
          end
        end
      end

      context "with an encrypted proposal" do
        let(:use_lvm) { false }
        let(:use_encryption) { true }

        context "if there are no EFI partitions" do
          let(:efi_partitions) { [] }

          it "requires only a new /boot/efi partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse: nil)
            )
          end
        end

        context "if there is already an EFI partition" do
          let(:efi_partitions) { [partition_double("/dev/sda1")] }

          it "only requires to use the existing EFI partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse: "/dev/sda1")
            )
          end
        end
      end
    end

    context "not using UEFI (legacy PC)" do
      let(:efiboot) { false }

      context "with GPT partition table" do
        let(:boot_ptable_type) { :gpt }

        context "in a partitions-based proposal" do
          let(:use_lvm) { false }

          context "if there is no GRUB partition" do
            let(:grub_partitions) { [] }

            it "requires a new GRUB partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_having_attributes(partition_id: bios_boot_id, reuse: nil)
              )
            end
          end

          context "if there is already a GRUB partition" do
            let(:grub_partitions) { [partition_double("/dev/sda2")] }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end
        end

        context "in a LVM-based proposal" do
          let(:use_lvm) { true }

          context "if there is no GRUB partition" do
            let(:grub_partitions) { [] }

            it "requires a new GRUB partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_having_attributes(partition_id: bios_boot_id, reuse: nil)
              )
            end
          end

          context "if there is already a GRUB partition" do
            let(:grub_partitions) { [partition_double("/dev/sda2")] }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end
        end

        context "in an encrypted proposal" do
          let(:use_lvm) { false }
          let(:use_encryption) { true }

          context "if there is no GRUB partition" do
            let(:grub_partitions) { [] }

            it "requires a new GRUB partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_having_attributes(partition_id: bios_boot_id, reuse: nil)
              )
            end
          end

          context "if there is already a GRUB partition" do
            let(:grub_partitions) { [partition_double("/dev/sda2")] }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end
        end
      end

      context "with a MS-DOS partition table" do
        let(:grub_partitions) { [] }
        let(:boot_ptable_type) { :msdos }

        context "if the MBR gap is big enough to embed Grub" do
          let(:mbr_gap_size) { 256.KiB }

          context "in a partitions-based proposal" do
            let(:use_lvm) { false }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end

          context "in a LVM-based proposal" do
            let(:use_lvm) { true }

            context "if the MBR gap has additional space for grubenv" do
              let(:mbr_gap_size) { 260.KiB }

              it "does not require any particular volume" do
                expect(checker.needed_partitions).to be_empty
              end
            end

            context "if the MBR gap has no additional space" do
              it "requires only a /boot partition" do
                expect(checker.needed_partitions).to contain_exactly(
                  an_object_having_attributes(mount_point: "/boot")
                )
              end
            end
          end

          context "in an encrypted proposal" do
            let(:use_lvm) { false }
            let(:use_encryption) { true }

            context "if the MBR gap has additional space for grubenv" do
              let(:mbr_gap_size) { 260.KiB }

              it "does not require any particular volume" do
                expect(checker.needed_partitions).to be_empty
              end
            end

            context "if the MBR gap has no additional space" do
              it "requires only a /boot partition" do
                expect(checker.needed_partitions).to contain_exactly(
                  an_object_having_attributes(mount_point: "/boot")
                )
              end
            end
          end
        end

        context "with too small MBR gap" do
          let(:mbr_gap_size) { 16.KiB }

          context "in a partitions-based proposal" do
            let(:use_lvm) { false }

            context "if proposing root (/) as Btrfs" do
              let(:use_btrfs) { true }

              it "does not require any particular volume" do
                expect(checker.needed_partitions).to be_empty
              end
            end

            context "if proposing root (/) as non-Btrfs" do
              let(:use_btrfs) { false }

              it "raises an exception" do
                expect { checker.needed_partitions }.to raise_error(
                  Y2Storage::BootRequirementsChecker::Error
                )
              end
            end
          end

          context "in a LVM-based proposal" do
            let(:use_lvm) { true }

            it "raises an exception" do
              expect { checker.needed_partitions }.to raise_error(
                Y2Storage::BootRequirementsChecker::Error
              )
            end
          end

          context "in an encrypted proposal" do
            let(:use_lvm) { false }
            let(:use_encryption) { true }

            it "raises an exception" do
              expect { checker.needed_partitions }.to raise_error(
                Y2Storage::BootRequirementsChecker::Error
              )
            end
          end
        end
      end

      context "when proposing a boot partition" do
        let(:boot_part) { find_vol("/boot", checker.needed_partitions(target)) }
        # Default values to ensure proposal of boot
        let(:efiboot) { false }
        let(:use_lvm) { true }
        let(:sda_part_table) { pt_msdos }
        let(:mbr_gap_size) { 256.KiB }

        include_examples "proposed boot partition"
      end

      context "when proposing an new GRUB partition" do
        let(:grub_part) { find_vol(nil, checker.needed_partitions(target)) }
        # Default values to ensure a GRUB partition
        let(:boot_ptable_type) { :gpt }
        let(:efiboot) { false }
        let(:grub_partitions) { {} }

        include_examples "proposed GRUB partition"
      end

      context "when proposing an new EFI partition" do
        let(:efi_part) { find_vol("/boot/efi", checker.needed_partitions(target)) }
        # Default values to ensure proposal of EFI partition
        let(:efiboot) { true }
        let(:efi_partitions) { [] }

        include_examples "proposed EFI partition"
      end
    end
  end
end
