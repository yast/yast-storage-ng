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
require "y2storage"

describe Y2Storage::BootRequirementsChecker do
  using Y2Storage::Refinements::SizeCasts

  describe "planning of partitions that are already there" do
    include_context "boot requirements"

    # Some general default values
    let(:architecture) { :x86 }
    let(:grub_partitions) { [] }
    let(:efiboot) { false }
    let(:efi_partitions) { [] }
    let(:other_efi_partitions) { [] }
    let(:use_lvm) { false }
    let(:mbr_gap_for_grub?) { false }

    before do
      allow(storage_arch).to receive(:efiboot?).and_return(efiboot)
      allow(dev_sda).to receive(:mbr_gap_for_grub?).and_return mbr_gap_for_grub?
      allow(dev_sda).to receive(:grub_partitions).and_return grub_partitions
      allow(dev_sda).to receive(:efi_partitions).and_return efi_partitions
      allow(dev_sda).to receive(:partitions).and_return(grub_partitions + efi_partitions)
      allow(dev_sdb).to receive(:efi_partitions).and_return(other_efi_partitions)
      allow(dev_sdb).to receive(:partitions).and_return(other_efi_partitions)
    end

    context "when /boot/efi is needed" do
      let(:efiboot) { true }

      before do
        allow(analyzer).to receive(:free_mountpoint?).with("/boot/efi")
          .and_return missing_efi
      end

      context "and /boot/efi is already in the list of planned partitions" do
        let(:missing_efi) { false }

        it "does not propose another /boot/efi" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "and there is no planned device for /boot/efi" do
        context "but something in the devicegraph is choosen as /boot/efi" do
          let(:missing_efi) { false }

          it "does not propose another /boot/efi" do
            expect(checker.needed_partitions).to be_empty
          end
        end

        context "and there is no /boot/efi in the devicegraph" do
          let(:missing_efi) { true }

          context "if there is suitable EFI partition in the devicegraph" do
            let(:efi_partitions) { [efi_partition] }

            let(:efi_partition) { partition_double("/dev/sda1") }

            before do
              allow(efi_partition).to receive(:match_volume?).and_return(true)
              allow(efi_partition).to receive(:id).and_return(Y2Storage::PartitionId::ESP)
            end

            it "proposes to use the existing EFI partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_having_attributes(mount_point: "/boot/efi", reuse_name: "/dev/sda1")
              )
            end
          end

          context "if there are no EFI partitions in the devicegraph" do
            let(:efi_partitions) { [] }

            it "proposes to create a new /boot/efi partition" do
              expect(checker.needed_partitions).to include(
                an_object_having_attributes(mount_point: "/boot/efi", reuse?: false)
              )
            end
          end
        end
      end
    end

    context "when a separate /boot is needed" do
      # Default values to ensure boot is needed
      let(:use_lvm) { true }
      let(:mbr_gap_for_grub?) { false }

      before do
        allow(analyzer).to receive(:free_mountpoint?).with("/boot")
          .and_return missing_boot
      end

      context "and /boot is already in the list of planned partitions" do
        let(:missing_boot) { false }

        it "does not propose another /boot" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "and there is no planned device for /boot" do
        context "but something in the devicegraph is choosen as /boot" do
          let(:missing_boot) { false }

          it "does not propose another /boot" do
            expect(checker.needed_partitions).to be_empty
          end
        end

        context "and there is no /boot in the devicegraph" do
          let(:missing_boot) { true }

          it "proposes to create a new /boot partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot", reuse?: false)
            )
          end
        end
      end
    end

    context "when a PReP partition is needed" do
      # Default values to ensure PReP is needed
      let(:use_lvm) { false }
      let(:architecture) { :ppc }
      let(:prep_partitions) { [] }

      before do
        allow(storage_arch).to receive(:ppc_power_nv?).and_return false
        allow(dev_sda).to receive(:partitions).and_return prep_partitions
      end

      context "and a suitable PReP is already in the list of planned partitions" do
        let(:planned_prep_partitions) { [planned_prep_partition] }

        let(:planned_prep_partition) { [planned_partition] }

        before do
          allow(planned_prep_partition).to receive(:match_volume?).and_return(true)
        end

        it "does not propose another PReP" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "and there is no PReP in the list of planned devices" do
        let(:planned_prep_partitions) { [] }

        context "and there are no PReP partitions in the target disk" do
          let(:prep_partitions) { [] }

          it "proposes to create a PReP partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(partition_id: Y2Storage::PartitionId::PREP)
            )
          end
        end

        context "but there is already a suitable PReP partition in the disk" do
          let(:prep_partitions) { [prep_partition] }

          let(:prep_partition) { partition_double("/dev/sda1") }

          before do
            allow(prep_partition).to receive(:match_volume?).and_return(true)
          end

          it "does not propose another PReP" do
            expect(checker.needed_partitions).to be_empty
          end
        end
      end
    end

    context "when /boot/zipl is needed" do
      # Default values to ensure the partition is needed
      let(:architecture) { :s390 }
      let(:dasd) { false }
      let(:type) { Y2Storage::DasdType::UNKNOWN }
      let(:format) { Y2Storage::DasdFormat::NONE }
      let(:use_lvm) { false }

      before do
        allow(dev_sda).to receive(:is?).with(:dasd).and_return(dasd)
        allow(dev_sda).to receive(:type).and_return(type)
        allow(dev_sda).to receive(:format).and_return(format)
        allow(analyzer).to receive(:free_mountpoint?).with("/boot/zipl")
          .and_return missing_zipl
      end

      context "and /boot/zipl is already in the list of planned partitions" do
        let(:missing_zipl) { false }

        it "does not propose another /boot/zipl" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "and there is no planned device for /boot/zipl" do
        context "but something in the devicegraph is choosen as /boot/zipl" do
          let(:missing_zipl) { false }

          it "does not propose another /boot" do
            expect(checker.needed_partitions).to be_empty
          end
        end

        context "and there is no /boot/zipl in the devicegraph" do
          let(:missing_zipl) { true }

          it "proposes to create a new /boot/zipl partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot/zipl", reuse?: false)
            )
          end
        end
      end
    end

    context "when a GRUB partition is needed" do
      # Default values to ensure the partition is needed
      let(:boot_ptable_type) { :gpt }

      context "and some GRUB is already in the list of planned partitions" do
        let(:planned_grub_partitions) { [planned_grub_partition] }

        before do
          allow(planned_grub_partition).to receive(:match_volume?).and_return(true)
        end

        let(:planned_grub_partition) { planned_partition }

        it "does not propose another GRUB partition" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "and there are no GRUB partitions in the list of planned devices" do
        let(:planned_grub_partitions) { [] }

        context "and there are no GRUB partitions in the target disk" do
          let(:grub_partitions) { [] }

          it "proposes to create a GRUB partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(partition_id: Y2Storage::PartitionId::BIOS_BOOT)
            )
          end
        end

        context "but there is already a GRUB partition in the disk" do
          let(:grub_partitions) { [grub_partition] }

          let(:grub_partition) { partition_double("/dev/sda1") }

          before do
            allow(grub_partition).to receive(:match_volume?).with(anything).and_return(true)
          end

          it "does not propose another GRUB partition" do
            expect(checker.needed_partitions).to be_empty
          end
        end
      end
    end
  end
end
