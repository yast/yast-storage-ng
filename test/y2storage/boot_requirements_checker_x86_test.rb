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
  describe "#needed_partitions in a x86 system" do
    using Y2Storage::Refinements::SizeCasts

    include_context "boot requirements"

    let(:architecture) { :x86 }

    context "using UEFI" do
      let(:efiboot) { true }

      include_context "plain UEFI"
    end

    context "not using UEFI (legacy PC)" do

      # Just to shorten
      let(:bios_boot_id) { Y2Storage::PartitionId::BIOS_BOOT }
      let(:efiboot) { false }

      context "with GPT partition table" do
        context "in a partitions-based proposal" do
          context "if there is no GRUB partition" do
            let(:scenario) { "trivial" }

            it "requires a new GRUB partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_having_attributes(partition_id: bios_boot_id, reuse_name: nil)
              )
            end
          end

          context "if there is already a GRUB partition" do
            let(:scenario) { "missing_bios_boot" }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end
        end

        context "in a LVM-based proposal" do
          context "if there is no GRUB partition" do
            let(:scenario) { "trivial_lvm" }

            it "requires a new GRUB partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_having_attributes(partition_id: bios_boot_id, reuse_name: nil)
              )
            end
          end

          context "if there is already a GRUB partition" do
            let(:scenario) { "lvm_with_bios_boot" }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end
        end

        context "in an encrypted proposal" do
          context "if there is no GRUB partition" do
            let(:scenario) { "trivial_encrypted" }

            it "requires a new GRUB partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_having_attributes(partition_id: bios_boot_id, reuse_name: nil)
              )
            end
          end

          context "if there is already a GRUB partition" do
            let(:scenario) { "encrypted_with_bios_boot" }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end
        end
      end

      context "with a MS-DOS partition table" do
        context "if the MBR gap is big enough to embed Grub" do
          context "in a partitions-based proposal" do
            let(:scenario) { "dos_btrfs_with_gap" }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end

          context "in a LVM-based proposal" do
            context "if the MBR gap has additional space for grubenv" do
              let(:scenario) { "dos_btrfs_lvm_enough_gap" }

              it "does not require any particular volume" do
                expect(checker.needed_partitions).to be_empty
              end
            end

            context "if the MBR gap has no additional space" do
              let(:scenario) { "dos_btrfs_lvm_min_gap" }

              it "requires only a /boot partition" do
                expect(checker.needed_partitions).to contain_exactly(
                  an_object_having_attributes(mount_point: "/boot")
                )
              end
            end
          end
        end

        context "with too small MBR gap" do
          context "in a partitions-based proposal" do
            context "if proposing root (/) as Btrfs" do
              let(:scenario) { "dos_btrfs_no_gap" }

              it "does not require any particular volume" do
                expect(checker.needed_partitions).to be_empty
              end
            end

            context "if proposing root (/) as non-Btrfs" do
              let(:scenario) { "dos_ext_no_gap" }

              it "raises an exception" do
                expect { checker.needed_partitions }.to raise_error(
                  Y2Storage::BootRequirementsChecker::Error
                )
              end
            end
          end

          context "in a LVM-based proposal" do
            let(:scenario) { "dos_btrfs_lvm_no_gap" }

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
        let(:grub_partitions) { [] }

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
