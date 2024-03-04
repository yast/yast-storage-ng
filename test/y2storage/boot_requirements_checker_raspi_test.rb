#!/usr/bin/env rspec
# Copyright (c) [2018-2019] SUSE LLC
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
  describe "#needed_partitions in a Raspberry Pi" do
    using Y2Storage::Refinements::SizeCasts

    include_context "boot requirements"

    # Some shortcuts
    let(:dos32_id) { Y2Storage::PartitionId::DOS32 }
    let(:esp_id) { Y2Storage::PartitionId::ESP }
    let(:vfat) { Y2Storage::Filesystems::Type::VFAT }

    def partition_double(number, filesystem)
      if number == 1
        start = 1
        id = first_partition_id
      else
        start = 2
        id = second_partition_id
      end
      region = Y2Storage::Region.create(start, 512, 512)

      double(
        "Partition", name: "/dev/sda#{number}", id: id, size: 256.MiB, match_volume?: false,
        filesystem: filesystem, direct_blk_filesystem: filesystem, region: region, sid: 42
      )
    end

    let(:architecture) { :aarch64 }
    let(:raspi_system) { true }
    let(:efi_partitions) { [] }
    let(:sda_partitions) { [] }
    let(:use_lvm) { false }
    let(:sda_ptable_type) { Y2Storage::PartitionTables::Type::MSDOS }

    let(:first_partition_id) { Y2Storage::PartitionId::LINUX }
    let(:second_partition_id) { Y2Storage::PartitionId::LINUX }

    let(:rpi_boot_fs) { double("BlkFilesystem", type: vfat, efi?: false, rpi_boot?: true) }
    let(:rpi_boot_sda) { partition_double(1, rpi_boot_fs) }
    let(:efi_fs) { double("BlkFilesystem", type: vfat, efi?: true, rpi_boot?: false) }

    before do
      allow(dev_sda).to receive(:efi_partitions).and_return efi_partitions
      allow(dev_sda).to receive(:partitions).and_return sda_partitions
      allow(dev_sda.partition_table).to receive(:type).and_return sda_ptable_type
    end

    RSpec.shared_examples "from scratch" do
      it "requires only a new /boot/efi partition" do
        expect(checker.needed_partitions).to contain_exactly(
          an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil)
        )
      end

      it "requires /boot/efi to be the first partition of the device" do
        planned = checker.needed_partitions.first
        expect(planned.max_start_offset).to eq 1.MiB
      end

      it "requires /boot/efi to be in a MBR partition table, bumping any existing table if needed" do
        planned = checker.needed_partitions.first
        expect(planned.ptable_type.to_sym).to eq :msdos
      end

      it "requires the /boot/efi partition to have id DOS32 (bootcode will be installed there)" do
        planned = checker.needed_partitions.first
        expect(planned.partition_id).to eq dos32_id
      end
    end

    context "if the target boot disk initially contains a MBR partition table" do
      let(:sda_ptable_type) { Y2Storage::PartitionTables::Type::MSDOS }

      context "and the first partition in the boot disk has id DOS32 and a FAT filesystem" do
        let(:first_partition_id) { dos32_id }

        context "and it contains an EFI directory" do
          let(:efi_partitions) { [partition_double(1, efi_fs)] }
          let(:sda_partitions) { efi_partitions }

          it "only requires to use the existing EFI partition (bootcode will be installed there)" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse_name: "/dev/sda1")
            )
          end
        end

        context "and it contains a Raspberry Pi boot code but no EFI directory" do
          context "and there is also a suitable standard EFI partition in the target disk" do
            let(:second_partition_id) { esp_id }
            let(:efi_partition) { partition_double(2, efi_fs) }
            let(:efi_partitions) { [efi_partition] }
            let(:sda_partitions) { [rpi_boot_sda, efi_partition] }
            before { expect(efi_partition).to receive(:match_volume?).and_return true }

            it "requires to mount at /boot/vc the firmware partition from the target disk" do
              expect(checker.needed_partitions).to include(
                an_object_having_attributes(mount_point: "/boot/vc", reuse_name: "/dev/sda1")
              )
            end

            it "requires to use the existing EFI partition" do
              expect(checker.needed_partitions).to include(
                an_object_having_attributes(mount_point: "/boot/efi", reuse_name: "/dev/sda2")
              )
            end
          end

          context "and there is no suitable EFI partition in the target disk" do
            let(:sda_partitions) { [rpi_boot_sda] }

            it "requires to mount at /boot/vc the firmware partition from the target disk" do
              expect(checker.needed_partitions).to include(
                an_object_having_attributes(mount_point: "/boot/vc", reuse_name: "/dev/sda1")
              )
            end

            it "requires a new /boot/efi partition" do
              expect(checker.needed_partitions).to include(
                an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil)
              )
            end

            it "does not enforce the /boot/efi partition to be the first" do
              planned = checker.needed_partitions.find { |part| part.mount_point == "/boot/efi" }
              expect(planned.max_start_offset).to be >= 1.MiB
            end

            it "requires the /boot/efi partition to have id ESP (according to the EFI standard)" do
              planned = checker.needed_partitions.find { |part| part.mount_point == "/boot/efi" }
              expect(planned.partition_id).to eq esp_id
            end
          end
        end

        context "and the first partition contains no boot code or EFI files" do
          let(:sda_partitions) { [partition_double(1, nil)] }

          include_examples "from scratch"
        end

        context "and there are no partitions in the boot disk" do
          let(:sda_partitions) { [] }

          include_examples "from scratch"
        end
      end

      context "and the first partition in the boot disk is a standard EFI with id ESP" do
        let(:first_partition_id) { esp_id }
        let(:efi_partitions) { [partition_double(1, efi_fs)] }
        let(:sda_partitions) { efi_partitions }

        include_examples "from scratch"
      end
    end

    context "if the target boot disk initially contains a GPT partition table" do
      let(:sda_ptable_type) { Y2Storage::PartitionTables::Type::GPT }

      context "even if the first partition has id DOS32 and a FAT filesystem with an EFI system" do
        let(:first_partition_id) { dos32_id }
        let(:efi_partitions) { [partition_double(1, efi_fs)] }
        let(:sda_partitions) { efi_partitions }

        include_examples "from scratch"
      end

      context "if there are no partitions in the boot disk" do
        let(:sda_partitions) { [] }

        include_examples "from scratch"
      end
    end

    context "if the target boot disk contains no partition table initially" do
      before do
        allow(dev_sda).to receive(:partition_table).and_return nil
      end

      include_examples "from scratch"
    end

    context "when proposing a new EFI partition" do
      let(:efi_part) { find_vol("/boot/efi", checker.needed_partitions(target)) }
      # FIXME: Default values to ensure proposal of EFI partition
      let(:sda_partitions) { [] }
      let(:sdb_partitions) { [] }
      let(:efi_partitions) { [] }

      include_examples "proposed EFI partition basics"
      include_examples "minimalistic EFI partition"
    end
  end
end
