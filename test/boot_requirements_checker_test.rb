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
require "storage/proposal"
require "storage/boot_requirements_checker"
require "storage/refinements/size_casts"

def find_vol(mount_point, volumes)
  volumes.find { |p| p.mount_point == mount_point }
end

describe Yast::Storage::BootRequirementsChecker do
  describe "#needed_partitions" do
    using Yast::Storage::Refinements::SizeCasts

    subject(:checker) { described_class.new(settings, analyzer) }

    let(:root_device) { "/dev/sda" }
    let(:settings) do
      settings = Yast::Storage::Proposal::Settings.new
      settings.root_device = root_device
      settings.use_lvm = use_lvm
      settings
    end
    let(:analyzer) { instance_double("Yast::Storage::DiskAnalyzer") }
    let(:storage_arch) { instance_double("::Storage::Arch") }
    let(:dev_sda) { instance_double("::Storage::Disk") }
    let(:pt_gpt) { instance_double("::Storage::PartitionTable") }
    let(:pt_msdos) { instance_double("::Storage::PartitionTable") }

    before do
      Yast::Storage::StorageManager.fake_from_yaml
      allow(Yast::Storage::StorageManager.instance).to receive(:arch).and_return(storage_arch)

      allow(storage_arch).to receive(:x86?).and_return(architecture == :x86)
      allow(storage_arch).to receive(:ppc?).and_return(architecture == :ppc)
      allow(storage_arch).to receive(:s390?).and_return(architecture == :s390)

      allow(dev_sda).to receive(:partition_table?).and_return(true)
      allow(dev_sda).to receive(:partition_table).and_return(pt_msdos)

      allow(pt_gpt).to receive(:type).and_return(::Storage::PtType_GPT)
      allow(pt_msdos).to receive(:type).and_return(::Storage::PtType_MSDOS)

      allow(analyzer).to receive(:device_by_name).with("/dev/sda").and_return(dev_sda)
      allow(analyzer).to receive(:grub_partitions).and_return({})
      allow(analyzer).to receive(:mbr_gap).and_return("/dev/sda" => Yast::Storage::DiskSize.kiB(300))
    end

    context "in a x86 system" do
      let(:architecture) { :x86 }

      before do
        allow(storage_arch).to receive(:efiboot?).and_return(efiboot)
      end

      context "using UEFI" do
        let(:efiboot) { true }

        before do
          allow(analyzer).to receive(:efi_partitions).and_return efi_partitions
        end

        context "with a partitions-based proposal" do
          let(:use_lvm) { false }

          context "if there are no EFI partitions" do
            let(:efi_partitions) { {} }

            it "requires only a new /boot/efi partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot/efi", reuse: nil)
              )
            end
          end

          context "if there is already an EFI partition" do
            let(:efi_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

            it "only requires to use the existing EFI partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot/efi", reuse: "/dev/sda1")
              )
            end
          end
        end

        context "with a LVM-based proposal" do
          let(:use_lvm) { true }

          context "if there are no EFI partitions" do
            let(:efi_partitions) { {} }

            it "requires /boot and a new /boot/efi partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot", reuse: nil),
                an_object_with_fields(mount_point: "/boot/efi", reuse: nil)
              )
            end
          end

          context "if there is already an EFI partition" do
            let(:efi_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

            it "requires /boot and a reused /boot/efi partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot", reuse: nil),
                an_object_with_fields(mount_point: "/boot/efi", reuse: "/dev/sda1")
              )
            end
          end
        end

        context "when proposing a boot partition" do
          let(:boot_part) { find_vol("/boot", checker.needed_partitions) }
          # Default values to ensure the max num of proposed volumes
          let(:use_lvm) { true }
          let(:efi_partitions) { {} }

          it "requires /boot to be ext4 with at least 100 MiB" do
            expect(boot_part.filesystem_type).to eq ::Storage::FsType_EXT4
            expect(boot_part.min_size).to eq 100.MiB
          end

          it "requires /boot to be in the system disk out of LVM" do
            expect(boot_part.disk).to eq root_device
            expect(boot_part.can_live_on_logical_volume).to eq false
          end

          it "recommends /boot to be 200 MiB" do
            expect(boot_part.desired_size).to eq 200.MiB
          end
        end

        context "when proposing an new EFI partition" do
          let(:efi_part) { find_vol("/boot/efi", checker.needed_partitions) }
          # Default values to ensure the max num of proposed volumes
          let(:use_lvm) { true }
          let(:efi_partitions) { {} }

          it "requires /boot/efi to be vfat with at least 33 MiB" do
            expect(efi_part.filesystem_type).to eq ::Storage::FsType_VFAT
            expect(efi_part.min_size).to eq 33.MiB
          end

          it "requires /boot/efi to be out of LVM" do
            expect(efi_part.can_live_on_logical_volume).to eq false
          end

          it "recommends /boot/efi to be 500 MiB" do
            expect(efi_part.desired_size).to eq 500.MiB
          end

          it "requires /boot/efi to be close enough to the beginning of disk" do
            expect(efi_part.max_start_offset).to eq 2.TiB
          end
        end
      end

      context "not using UEFI (legacy PC)" do
        let(:efiboot) { false }

        context "with a partitions-based proposal" do
          let(:use_lvm) { false }

          it "does not require any particular volume" do
            expect(checker.needed_partitions).to be_empty
          end
        end

        context "with a LVM-based proposal" do
          let(:use_lvm) { true }

          it "requires only a /boot partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_with_fields(mount_point: "/boot")
            )
          end

          it "requires /boot to be ext4 with at least 100 MiB" do
            boot_part = find_vol("/boot", checker.needed_partitions)
            expect(boot_part.filesystem_type).to eq ::Storage::FsType_EXT4
            expect(boot_part.min_size).to eq 100.MiB
          end

          it "requires /boot to be in the system disk out of the LVM" do
            boot_part = find_vol("/boot", checker.needed_partitions)
            expect(boot_part.disk).to eq root_device
            expect(boot_part.can_live_on_logical_volume).to eq false
          end

          it "recommends /boot to be 200 MiB" do
            boot_part = find_vol("/boot", checker.needed_partitions)
            expect(boot_part.desired_size).to eq 200.MiB
          end
        end
      end
    end

    context "in a PPC64 system" do
      let(:architecture) { :ppc }
      let(:prep_id) { ::Storage::ID_PPC_PREP }

      before do
        allow(storage_arch).to receive(:ppc_power_nv?).and_return(power_nv)
        allow(analyzer).to receive(:prep_partitions).and_return prep_partitions
      end

      context "in a non-PowerNV system (KVM/LPAR)" do
        let(:power_nv) { false }

        context "with a partitions-based proposal" do
          let(:use_lvm) { false }

          context "if there are no PReP partitions" do
            let(:prep_partitions) { { "/dev/sda" => [] } }

            it "requires only a PReP partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: nil, partition_id: prep_id)
              )
            end
          end

          context "if the existent PReP partition is not in the target disk" do
            let(:prep_partitions) { { "/dev/sdb" => [analyzer_part("/dev/sdb")] } }

            it "requires only a PReP partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: nil, partition_id: prep_id)
              )
            end
          end

          context "if there is already a PReP partition in the disk" do
            let(:prep_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

            it "does not require any particular volume" do
              expect(checker.needed_partitions).to be_empty
            end
          end
        end

        context "with a LVM-based proposal" do
          let(:use_lvm) { true }

          context "if there are no PReP partitions" do
            let(:prep_partitions) { { "/dev/sda" => [] } }

            it "requires /boot and PReP partitions" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot"),
                an_object_with_fields(mount_point: nil, partition_id: prep_id)
              )
            end
          end

          context "if the existent PReP partition is not in the target disk" do
            let(:prep_partitions) { { "/dev/sdb" => [analyzer_part("/dev/sdb1")] } }

            it "requires /boot and PReP partitions" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot"),
                an_object_with_fields(mount_point: nil, partition_id: prep_id)
              )
            end
          end

          context "if there is already a PReP partition in the disk" do
            let(:prep_partitions) { { "/dev/sda" => [analyzer_part("/dev/sda1")] } }

            it "only requires a /boot partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_with_fields(mount_point: "/boot")
              )
            end
          end
        end
      end

      context "in bare metal (PowerNV)" do
        let(:power_nv) { true }
        let(:prep_partitions) { {} }

        context "with a partitions-based proposal" do
          let(:use_lvm) { false }

          it "does not require any particular volume" do
            expect(checker.needed_partitions).to be_empty
          end
        end

        context "with a LVM-based proposal" do
          let(:use_lvm) { true }

          it "requires only a /boot partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_with_fields(mount_point: "/boot")
            )
          end
        end
      end

      context "when proposing a boot partition" do
        let(:boot_part) { find_vol("/boot", checker.needed_partitions) }
        # Default values to ensure the max num of proposed volumes
        let(:prep_partitions) { {} }
        let(:use_lvm) { true }
        let(:power_nv) { false }

        it "requires /boot to be ext4 with at least 100 MiB" do
          expect(boot_part.filesystem_type).to eq ::Storage::FsType_EXT4
          expect(boot_part.min_size).to eq 100.MiB
        end

        it "requires /boot to be in the system disk out of LVM" do
          expect(boot_part.disk).to eq root_device
          expect(boot_part.can_live_on_logical_volume).to eq false
        end

        it "recommends /boot to be 200 MiB" do
          expect(boot_part.desired_size).to eq 200.MiB
        end
      end

      context "when proposing a PReP partition" do
        let(:prep_part) { find_vol(nil, checker.needed_partitions) }
        # Default values to ensure the max num of proposed volumes
        let(:prep_partitions) { {} }
        let(:use_lvm) { true }
        let(:power_nv) { false }

        it "requires it to be between 256kiB and 8MiB, despite the alignment" do
          expect(prep_part.min_size).to eq 256.kiB
          expect(prep_part.max_size).to eq 8.MiB
          expect(prep_part.align).to eq :keep_size
        end

        it "recommends it to be 1 MiB" do
          expect(prep_part.desired_size).to eq 1.MiB
        end

        it "requires it to be out of LVM" do
          expect(prep_part.can_live_on_logical_volume).to eq false
        end

        it "requires it to be bootable (ms-dos partition table)" do
          expect(prep_part.bootable).to eq true
        end
      end
    end
  end
end
