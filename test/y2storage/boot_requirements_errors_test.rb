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

  let(:scenario) { "trivial" }

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
      let(:errors) { [Y2Storage::SetupError.new(message: "test")] }

      it "returns false" do
        expect(checker.valid?).to eq(false)
      end
    end

    context "when there are warnings" do
      let(:warnings) { [Y2Storage::SetupError.new(message: "test")] }

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
    RSpec.shared_examples "no errors" do
      it "does not contain an error" do
        expect(checker.warnings).to be_empty
      end
    end

    RSpec.shared_examples "missing boot partition" do
      it "contains an error for missing boot partition" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        message = checker.warnings.first.message
        expect(message).to match(/Missing device for \/boot/)
      end
    end

    RSpec.shared_examples "missing prep partition" do
      it "contains an error for missing PReP partition" do
        expect(checker.warnings.size).to eq(1)
        expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

        message = checker.warnings.first.message
        expect(message).to match(/Missing device.* partition id prep/)
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
        # we want to test real scenarios which does not work well with shared examples
        # include_examples "missing boot partition"
      end

      context "and there is a /boot partition in the system" do
        # we want to test real scenarios which does not work well with shared examples
        xit "does not contain errors" do
          expect(checker.warnings).to be_empty
        end
      end
    end

    RSpec.shared_examples "efi partition" do
      context "when there is no /boot/efi partition in the system" do
        let(:scenario) { "trivial" }

        it "contains an error for the efi partition" do
          expect(checker.warnings.size).to eq(1)
          expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

          message = checker.warnings.first.message
          expect(message).to match(/Missing device for \/boot\/efi/)
        end
      end

      context "when there is a /boot/efi partition in the system" do
        let(:scenario) { "efi" }
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
        it "does not contain errors" do
          allow(checker.send(:strategy).boot_disk).to receive(:mbr_gap).and_return(260.KiB)
          expect(checker.warnings).to be_empty
        end
      end

      context "if the MBR gap has no additional space" do
        before do
          allow(checker.send(:strategy).boot_disk).to receive(:mbr_gap).and_return(256.KiB)
        end

        xit "it contains error if there is no separate /boot" do
          # how to mock it as shared example? we need real scenario
          # and for that shared examples does not look well.
        end
      end
    end

    let(:efiboot) { false }

    context "/boot is too small" do
      let(:scenario) { "small_boot" }

      before do
        allow_any_instance_of(Y2Storage::Mountable).to receive(:detect_space_info)
          .and_return(double(free: Y2Storage::DiskSize.MiB(1)))
      end

      it "contains an error when there is /boot that is not big enough" do
        expect(checker.errors.size).to eq(1)
        expect(checker.errors).to all(be_a(Y2Storage::SetupError))

        message = checker.errors.first.message
        expect(message).to match(/too small/)
      end
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
          let(:scenario) { "false-swaps" }
          include_examples "unknown boot disk"
        end

        context "when boot device has a GPT partition table" do
          context "and there is no a grub partition in the system" do
            let(:scenario) { "gpt_without_grub" }

            it "contains an error for missing grub partition" do
              expect(checker.warnings.size).to eq(1)
              expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

              message = checker.warnings.first.message
              expect(message).to match(/Missing device.*partition id bios_boot/)
            end
          end

          context "and there is a grub partition in the system" do
            it "does not contain errors" do
              expect(checker.warnings).to be_empty
            end
          end
        end

        context "with a MS-DOS partition table" do
          context "with a too small MBR gap" do
            context "in a plain btrfs setup" do
              let(:scenario) { "dos_btrfs_no_gap" }

              it "does not contain errors" do
                expect(checker.warnings).to be_empty
              end
            end

            context "in a not plain btrfs setup" do
              let(:scenario) { "dos_btrfs_lvm_no_gap" }

              it "contains an error for small MBR gap" do
                expect(checker.warnings.size).to eq(1)
                expect(checker.warnings).to all(be_a(Y2Storage::SetupError))

                message = checker.warnings.first.message
                expect(message).to match(/gap size is not enough/)
              end
            end
          end

          context "if the MBR gap is big enough to embed Grub" do
            context "in a partitions-based setup" do
              let(:scenario) { "dos_btrfs_with_gap" }

              it "does not contain errors" do
                expect(checker.warnings).to be_empty
              end
            end

            context "in a LVM-based setup" do
              # examples define own gap
              let(:scenario) { "dos_btrfs_lvm_no_gap" }

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

      let(:power_nv) { false }

      context "when there is no root" do
        let(:scenario) { "false-swaps" }
        include_examples "unknown boot disk"
      end

      context "in a non-PowerNV system (KVM/LPAR)" do
        let(:power_nv) { false }

        context "with a partitions-based proposal" do

          context "there is a PReP partition" do
            let(:scenario) { "prep" }
            include_examples "no errors"
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial" }
            include_examples "missing prep partition"
          end
        end

        context "with a LVM-based proposal" do
          context "there is a PReP partition" do
            let(:scenario) { "prep_lvm" }
            include_examples "no errors"
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial_lvm" }
            include_examples "missing prep partition"
          end
        end

        # sorry, but I won't write it in xml and yaml does not support it
        # scenario generator would be great
        xcontext "with a Software RAID proposal" do
          context "there is a PReP partition" do
            let(:scenario) { "prep_raid" }
            include_examples "no errors"
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial_raid" }
            include_examples "missing prep partition"
          end
        end

        context "with an encrypted proposal" do
          context "there is a PReP partition" do
            let(:scenario) { "prep_encrypted" }
            include_examples "no errors"
          end

          context "PReP partition missing" do
            let(:scenario) { "trivial_encrypted" }
            include_examples "missing prep partition"
          end
        end
      end

      context "in bare metal (PowerNV)" do
        let(:power_nv) { true }

        context "with a partitions-based proposal" do
          let(:scenario) { "trivial" }

          include_examples "no errors"
        end

        context "with a LVM-based proposal" do
          context "and there is no /boot partition in the system" do
            let(:scenario) { "trivial_lvm" }

            include_examples "missing boot partition"
          end

          context "and there is a /boot partition in the system" do
            let(:scenario) { "lvm_with_boot" }

            it "does not contain errors" do
              include_examples "no errors"
            end
          end
        end

        context "with a Software RAID proposal" do
          include_examples "boot partition"
        end

        context "with an encrypted proposal" do
          include_examples "boot partition"
        end
      end
    end

    context "in a S/390 system" do
      let(:architecture) { :s390 }
      let(:efiboot) { false }

      context "when there is no root" do
        let(:scenario) { "false-swaps" }

        include_examples "unknown boot disk"
      end

      # TODO: find coresponding xml files for it
      # and ideally from real usage
      xcontext "using a zfcp disk as boot disk" do
        let(:dasd) { false }
        let(:type) { Y2Storage::DasdType::UNKNOWN }
        let(:format) { Y2Storage::DasdFormat::NONE }

        include_examples "zipl partition"
      end

      xcontext "using a FBA DASD disk as boot disk" do
        let(:dasd) { true }
        let(:type) { Y2Storage::DasdType::FBA }
        include_examples "unsupported boot disk"
      end

      xcontext "using a (E)CKD DASD disk as boot disk" do
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
