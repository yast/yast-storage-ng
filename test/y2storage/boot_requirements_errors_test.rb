#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require_relative "#{TEST_PATH}/support/boot_requirements_context"
require "y2storage"

describe Y2Storage::BootRequirementsChecker do
  using Y2Storage::Refinements::SizeCasts

  include_context "boot requirements"

  let(:architecture) { :x86_64 }

  describe "#valid?" do
    let(:errors) { [] }
    let(:warnings) { [] }

    before do
      allow(checker).to receive(:errors).and_return(errors)
      allow(checker).to receive(:warnings).and_return(warnings)
    end

    context "when there are errors" do
      let(:errors) { [instance_double(Y2Storage::SetupError)] }

      it "returns false" do
        expect(checker.valid?).to eq(false)
      end
    end

    context "when there are warnings" do
      let(:warnings) { [instance_double(Y2Storage::SetupError)] }

      it "returns false" do
        expect(checker.valid?).to eq(false)
      end
    end

    context "when there are no errors neither warnings" do
      let(:errors) { [] }
      let(:warnings) { [] }

      it "returns true" do
        expect(checker.valid?).to eq(true)
      end
    end
  end

  describe "#errors" do
    RSpec.shared_examples "missing boot partition" do
      it "contains an error for missing boot partition" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        missing_volume = checker.warnings.first.missing_volume
        expect(missing_volume).to eq(boot_volume)
      end
    end

    RSpec.shared_examples "missing prep partition" do
      it "contains an error for missing PReP partition" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        missing_volume = checker.warnings.first.missing_volume
        expect(missing_volume).to eq(prep_volume)
      end
    end

    RSpec.shared_examples "missing zipl partition" do
      it "contains an error for missing ZIPL partition" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        missing_volume = checker.warnings.first.missing_volume
        expect(missing_volume).to eq(zipl_volume)
      end
    end

    RSpec.shared_examples "unknown boot disk" do
      it "contains an fatal error for unknown boot disk" do
        expect(checker.errors.size).to eq(1)
        expect(checker.errors).to all(be_a(Y2Storage::SetupError))

        message = checker.errors.first.message
        expect(message).to match(/no device mounted at '\/'/)
      end
    end

    RSpec.shared_examples "unsupported boot disk" do
      it "contains an error for unsupported boot disk" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        message = checker.warnings.first.message
        expect(message).to match(/is not supported/)
      end
    end

    RSpec.shared_examples "boot partition" do
      context "and there is no /boot partition in the system" do
        let(:partitions) { [grub_partition] }
        include_examples "missing boot partition"
      end

      context "and there is a /boot partition in the system" do
        let(:partitions) { [boot_partition] }

        it "does not contain errors" do
          expect(checker.warnings).to be_empty
        end
      end
    end

    RSpec.shared_examples "efi partition" do
      context "when there is no /boot/efi partition in the system" do
        let(:partitions) { [boot_partition, grub_partition] }

        it "contains an error for the efi partition" do
          expect(checker.warnings.size).to eq(1)
          expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

          missing_volume = checker.warnings.first.missing_volume
          expect(missing_volume).to eq(efi_volume)
        end
      end

      context "when there is a /boot/efi partition in the system" do
        let(:partitions) { [boot_partition, efi_partition] }

        it "does not contain errors" do
          expect(checker.warnings).to be_empty
        end
      end
    end

    RSpec.shared_examples "zipl partition" do
      context "and there is no /boot/zipl partition in the system" do
        let(:partitions) { [grub_partition] }
        include_examples "missing zipl partition"
      end

      context "and there is a /boot/zipl partition in the system" do
        let(:partitions) { [zipl_partition] }

        it "does not contain errors" do
          expect(checker.warnings).to be_empty
        end
      end
    end

    RSpec.shared_examples "MBR gap" do
      context "if the MBR gap has additional space for grubenv" do
        let(:mbr_gap_size) { 260.KiB }

        it "does not contain errors" do
          expect(checker.warnings).to be_empty
        end
      end

      context "if the MBR gap has no additional space" do
        let(:mbr_gap_size) { 256.KiB }
        include_examples "boot partition"
      end
    end

    RSpec.shared_examples "PReP partition" do
      context "and there is no a PReP partition in the system" do
        let(:partitions) { [boot_partition] }
        include_examples "missing prep partition"
      end

      context "and there is a PReP partition in the system" do
        let(:partitions) { [boot_partition, prep_partition] }

        it "does not contain errors" do
          expect(checker.warnings).to be_empty
        end
      end
    end

    before do
      allow(storage_arch).to receive(:efiboot?).and_return(efiboot)

      allow_any_instance_of(Y2Storage::BootRequirementsStrategies::Base)
        .to receive(:boot_volume).and_return(boot_volume)

      allow_any_instance_of(Y2Storage::BootRequirementsStrategies::UEFI)
        .to receive(:efi_volume).and_return(efi_volume)

      allow_any_instance_of(Y2Storage::BootRequirementsStrategies::Legacy)
        .to receive(:grub_volume).and_return(grub_volume)

      allow_any_instance_of(Y2Storage::BootRequirementsStrategies::PReP)
        .to receive(:prep_volume).and_return(prep_volume)

      allow_any_instance_of(Y2Storage::BootRequirementsStrategies::ZIPL)
        .to receive(:zipl_volume).and_return(zipl_volume)

      allow(Y2Storage::Partition).to receive(:all).and_return partitions

      allow(boot_partition).to receive(:match_volume?).with(anything).and_return(false)
      allow(boot_partition).to receive(:match_volume?).with(boot_volume).and_return(true)

      allow(efi_partition).to receive(:match_volume?).with(anything).and_return(false)
      allow(efi_partition).to receive(:match_volume?).with(efi_volume).and_return(true)

      allow(grub_partition).to receive(:match_volume?).with(anything).and_return(false)
      allow(grub_partition).to receive(:match_volume?).with(grub_volume).and_return(true)

      allow(prep_partition).to receive(:match_volume?).with(anything).and_return(false)
      allow(prep_partition).to receive(:match_volume?).with(prep_volume).and_return(true)

      allow(zipl_partition).to receive(:match_volume?).with(anything).and_return(false)
      allow(zipl_partition).to receive(:match_volume?).with(zipl_volume).and_return(true)
    end

    let(:boot_volume) { instance_double(Y2Storage::VolumeSpecification) }

    let(:efi_volume) { instance_double(Y2Storage::VolumeSpecification) }

    let(:grub_volume) { instance_double(Y2Storage::VolumeSpecification) }

    let(:prep_volume) { instance_double(Y2Storage::VolumeSpecification) }

    let(:zipl_volume) { instance_double(Y2Storage::VolumeSpecification) }

    let(:partitions) { [] }

    let(:boot_partition) { partition_double("/dev/sda1") }

    let(:efi_partition) { partition_double("/dev/sda1") }

    let(:grub_partition) { partition_double("/dev/sda1") }

    let(:prep_partition) { partition_double("/dev/sda1") }

    let(:zipl_partition) { partition_double("/dev/sda1") }

    let(:efiboot) { true }

    it "contains an error when there is /boot that is not big enough" do
      allow(devicegraph).to receive(:filesystems)
        .and_return([double(
          mount_point: "/boot",
          blk_devices: [double(size: Y2Storage::DiskSize.MiB(50))]
        )])
      expect(checker.errors.size).to eq(1)
      expect(checker.errors).to all(be_a(Y2Storage::SetupError))

      message = checker.errors.first.message
      expect(message).to match(/too small/)
    end

    context "in a x86 system" do
      let(:architecture) { :x86 }

      context "using UEFI" do
        let(:efiboot) { true }
        include_examples "efi partition"
      end

      context "not using UEFI (legacy PC)" do
        let(:efiboot) { false }

        context "when there is no root" do
          let(:root_filesystem) { nil }
          include_examples "unknown boot disk"
        end

        context "when boot device has no partition table" do
          let(:boot_partition_table) { nil }

          it "contains a fatal error for unknown partition table" do
            expect(checker.errors.size).to eq(1)
            expect(checker.errors).to all(be_a(Y2Storage::SetupError))

            message = checker.errors.first.message
            expect(message).to match(/partition table/)
          end
        end

        context "when boot device has a GPT partition table" do
          let(:boot_ptable_type) { :gpt }

          context "and there is no a grub partition in the system" do
            let(:partitions) { [boot_partition] }

            it "contains an error for missing grub partition" do
              expect(checker.warnings.size).to eq(1)
              expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

              missing_volume = checker.warnings.first.missing_volume
              expect(missing_volume).to eq(grub_volume)
            end
          end

          context "and there is a grub partition in the system" do
            let(:partitions) { [boot_partition, grub_partition] }

            it "does not contain errors" do
              expect(checker.warnings).to be_empty
            end
          end
        end

        context "with a MS-DOS partition table" do
          let(:boot_ptable_type) { :msdos }

          before do
            allow(dev_sda).to receive(:mbr_gap).and_return mbr_gap_size
          end

          let(:mbr_gap_size) { Y2Storage::DiskSize.zero }

          context "with a too small MBR gap" do
            let(:mbr_gap_size) { 16.KiB }

            context "in a plain btrfs setup" do
              let(:use_lvm) { false }
              let(:use_raid) { false }
              let(:use_encryption) { false }
              let(:use_btrfs) { true }

              it "does not contain errors" do
                expect(checker.warnings).to be_empty
              end
            end

            context "in a not plain btrfs setup" do
              let(:use_lvm) { true }
              let(:use_btrfs) { true }

              it "contains an error for small MBR gap" do
                expect(checker.warnings.size).to eq(1)
                expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

                message = checker.warnings.first.message
                expect(message).to match(/gap size is not enough/)
              end
            end
          end

          context "if the MBR gap is big enough to embed Grub" do
            let(:mbr_gap_size) { 256.KiB }

            context "in a partitions-based setup" do
              let(:use_lvm) { false }

              it "does not contain errors" do
                expect(checker.warnings).to be_empty
              end
            end

            context "in a LVM-based setup" do
              let(:use_lvm) { true }
              include_examples "MBR gap"
            end

            context "in a Software RAID setup" do
              let(:use_raid) { true }
              include_examples "MBR gap"
            end

            context "in an encrypted setup" do
              let(:use_lvm) { false }
              let(:use_encryption) { true }
              include_examples "MBR gap"
            end
          end
        end
      end
    end

    context "in an aarch64 system" do
      let(:architecture) { :aarch64 }
      # it's always UEFI
      let(:efiboot) { true }
      include_examples "efi partition"
    end

    context "in a PPC64 system" do
      let(:architecture) { :ppc }
      let(:efiboot) { false }
      let(:prep_id) { Y2Storage::PartitionId::PREP }

      before do
        allow(storage_arch).to receive(:ppc_power_nv?).and_return(power_nv)
      end

      let(:power_nv) { false }

      context "when there is no root" do
        let(:root_filesystem) { nil }
        include_examples "unknown boot disk"
      end

      context "in a non-PowerNV system (KVM/LPAR)" do
        let(:power_nv) { false }

        context "with a partitions-based proposal" do
          let(:use_lvm) { false }
          include_examples "PReP partition"
        end

        context "with a LVM-based proposal" do
          let(:use_lvm) { true }
          include_examples "PReP partition"
        end

        context "with a Software RAID proposal" do
          let(:use_raid) { true }
          include_examples "PReP partition"
        end

        context "with an encrypted proposal" do
          let(:use_lvm) { false }
          let(:use_encryption) { true }
          include_examples "PReP partition"
        end
      end

      context "in bare metal (PowerNV)" do
        let(:power_nv) { true }

        context "with a partitions-based proposal" do
          let(:use_lvm) { false }

          it "does not contain errors" do
            expect(checker.warnings).to be_empty
          end
        end

        context "with a LVM-based proposal" do
          let(:use_lvm) { true }
          include_examples "boot partition"
        end

        context "with a Software RAID proposal" do
          let(:use_lvm) { true }
          include_examples "boot partition"
        end

        context "with an encrypted proposal" do
          let(:use_lvm) { false }
          let(:use_encryption) { true }
          include_examples "boot partition"
        end
      end
    end

    context "in a S/390 system" do
      let(:architecture) { :s390 }
      let(:efiboot) { false }
      let(:use_lvm) { false }
      let(:partitions) { [zipl_partition] }

      before do
        allow(dev_sda).to receive(:is?).with(:dasd).and_return(dasd)
        allow(dev_sda).to receive(:type).and_return(type)
        allow(dev_sda).to receive(:format).and_return(format)
      end

      let(:dasd) { false }
      let(:type) { Y2Storage::DasdType::UNKNOWN }
      let(:format) { Y2Storage::DasdFormat::NONE }

      context "when there is no root" do
        let(:root_filesystem) { nil }
        include_examples "unknown boot disk"
      end

      context "using a zfcp disk as boot disk" do
        let(:dasd) { false }
        let(:type) { Y2Storage::DasdType::UNKNOWN }
        let(:format) { Y2Storage::DasdFormat::NONE }

        include_examples "zipl partition"
      end

      context "using a FBA DASD disk as boot disk" do
        let(:dasd) { true }
        let(:type) { Y2Storage::DasdType::FBA }
        include_examples "unsupported boot disk"
      end

      context "using a (E)CKD DASD disk as boot disk" do
        let(:dasd) { true }
        let(:type) { Y2Storage::DasdType::ECKD }

        context "if the disk is formatted as LDL" do
          let(:format) { Y2Storage::DasdFormat::LDL }
          include_examples "unsupported boot disk"
        end

        context "if the disk is formatted as CDL" do
          let(:format) { Y2Storage::DasdFormat::CDL }
          include_examples "zipl partition"
        end
      end
    end
  end
end
