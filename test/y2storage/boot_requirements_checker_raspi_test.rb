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
require_relative "#{TEST_PATH}/support/proposed_partitions_examples"
require_relative "#{TEST_PATH}/support/boot_requirements_context"
require "y2storage"

describe Y2Storage::BootRequirementsChecker do
  describe "#needed_partitions in a Raspberry Pi" do
    using Y2Storage::Refinements::SizeCasts

    include_context "boot requirements"

    def rpi_boot_double(name)
      region = Y2Storage::Region.create(1, 512, 512)
      double(
        "Partition", name: name,
        direct_blk_filesystem: rpi_boot_fs, region: region, match_volume?: false
      )
    end

    let(:architecture) { :aarch64 }
    let(:raspi_system) { true }
    let(:efi_partitions) { [] }
    let(:use_lvm) { false }
    let(:sdb_ptable) { double("PartitionTable", type: sdb_ptable_type) }
    let(:sda_ptable_type) { Y2Storage::PartitionTables::Type::MSDOS }
    let(:sdb_ptable_type) { Y2Storage::PartitionTables::Type::MSDOS }

    let(:rpi_boot_sda) { rpi_boot_double("/dev/sda1") }
    let(:rpi_boot_sdb) { rpi_boot_double("/dev/sdb1") }
    let(:rpi_boot_fs) { double("BlkFilesystem", type: Y2Storage::Filesystems::Type::VFAT) }
    let(:rpi_boot_existing_fs) { double("ExistingFilesystem", rpi_boot?: true) }

    before do
      allow(dev_sda).to receive(:efi_partitions).and_return efi_partitions
      allow(dev_sda).to receive(:partitions).and_return sda_partitions
      allow(dev_sda.partition_table).to receive(:type).and_return sda_ptable_type

      allow(dev_sdb).to receive(:efi_partitions).and_return []
      allow(dev_sdb).to receive(:partitions).and_return sdb_partitions
      allow(dev_sdb).to receive(:partition_table).and_return sdb_ptable

      allow(Y2Storage::ExistingFilesystem).to receive(:new).and_return rpi_boot_existing_fs
    end

    RSpec.shared_context "Raspberry Pi partitions" do
      context "if there are no EFI partitions" do
        let(:efi_partitions) { [] }

        context "and there are firmware partitions in several disks, including the target" do
          let(:sda_partitions) { [rpi_boot_sda] }
          let(:sdb_partitions) { [rpi_boot_sdb] }

          it "requires a new /boot/efi partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil)
            )
          end

          it "requires to mount at /boot/vc the firmware partition from the target disk" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot/vc", reuse_name: "/dev/sda1")
            )
          end
        end

        context "and there is a firmware partition in another disk" do
          let(:sda_partitions) { [] }
          let(:sdb_partitions) { [rpi_boot_sdb] }

          it "requires a new /boot/efi partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil)
            )
          end

          it "requires to mount the existing firmware partition at /boot/vc" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot/vc", reuse_name: "/dev/sdb1")
            )
          end
        end

        context "and there is no firmware partition in the system" do
          let(:sda_partitions) { [] }
          let(:sdb_partitions) { [] }

          it "requires only a new /boot/efi partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse_name: nil)
            )
          end
        end
      end

      context "if there is suitable EFI partition" do
        let(:efi_partitions) { [efi_partition] }
        let(:efi_partition) do
          double(
            "Partition", name: "/dev/sda2", size: 256.MiB, match_volume?: true,
            direct_blk_filesystem: nil, region: Y2Storage::Region.create(2, 512, 512),
            id: Y2Storage::PartitionId::ESP
          )
        end

        context "and there are firmware partitions in several disks, including the target" do
          let(:sda_partitions) { [rpi_boot_sda, efi_partition] }
          let(:sdb_partitions) { [rpi_boot_sdb] }

          it "requires to use the existing EFI partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot/efi", reuse_name: "/dev/sda2")
            )
          end

          it "requires to mount at /boot/vc the firmware partition from the target disk" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot/vc", reuse_name: "/dev/sda1")
            )
          end
        end

        context "and there is a firmware partition in another disk" do
          let(:sda_partitions) { [efi_partition] }
          let(:sdb_partitions) { [rpi_boot_sdb] }

          it "requires to use the existing EFI partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot/efi", reuse_name: "/dev/sda2")
            )
          end

          it "requires to mount the existing firmware partition at /boot/vc" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot/vc", reuse_name: "/dev/sdb1")
            )
          end
        end

        context "and there is no firmware partition in the system" do
          let(:sda_partitions) { [efi_partition] }
          let(:sdb_partitions) { [] }

          it "only requires to use the existing EFI partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot/efi", reuse_name: "/dev/sda2")
            )
          end
        end
      end
    end

    context "with a partitions-based proposal" do
      let(:use_lvm) { false }

      include_context "Raspberry Pi partitions"
    end

    context "with a LVM-based proposal" do
      let(:use_lvm) { true }

      include_context "Raspberry Pi partitions"
    end

    context "with an encrypted proposal" do
      let(:use_lvm) { false }
      let(:use_encryption) { true }

      include_context "Raspberry Pi partitions"
    end

    context "when proposing an new EFI partition" do
      let(:efi_part) { find_vol("/boot/efi", checker.needed_partitions(target)) }
      # FIXME: Default values to ensure proposal of EFI partition
      let(:sda_partitions) { [] }
      let(:sdb_partitions) { [] }
      let(:efi_partitions) { [] }

      include_examples "proposed EFI partition"
    end
  end
end
