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
require_relative "#{TEST_PATH}/support/boot_requirements_context"
require "y2storage"

describe Y2Storage::BootRequirementsChecker do
  using Y2Storage::Refinements::SizeCasts

  # TODO: adapt to use scenarios
  describe "planning of partitions that are already there" do
    include_context "boot requirements"

    # Some general default values
    let(:architecture) { :x86 }
    let(:efiboot) { false }

    context "when /boot/efi is needed" do
      let(:efiboot) { true }
      let(:scenario) { "trivial" }

      context "and /boot/efi is already in the list of planned partitions" do
        subject(:checker) do
          described_class.new(
            fake_devicegraph,
            planned_devices:
              [Y2Storage::Planned::Partition.new("/boot/efi", Y2Storage::Filesystems::Type::VFAT)]
          )
        end

        it "does not propose another /boot/efi" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "and there is no planned device for /boot/efi" do
        context "but something in the devicegraph is choosen as /boot/efi" do
          let(:scenario) { "efi" }

          it "does not propose another /boot/efi" do
            expect(checker.needed_partitions).to be_empty
          end
        end

        context "and there is no /boot/efi in the devicegraph" do
          let(:scenario) { "trivial" }

          context "if there is suitable EFI partition in the devicegraph" do
            let(:scenario) { "efi_not_mounted" }

            it "proposes to use the existing EFI partition" do
              expect(checker.needed_partitions).to contain_exactly(
                an_object_having_attributes(mount_point: "/boot/efi", reuse_name: "/dev/sda1")
              )
            end
          end

          context "if there are no EFI partitions in the devicegraph" do
            let(:scenario) { "trivial" }

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
      let(:architecture) { :ppc }
      let(:power_nv) { true }
      let(:scenario) { "dos_lvm" }

      context "and /boot is already in the list of planned partitions" do
        subject(:checker) do
          described_class.new(
            fake_devicegraph,
            planned_devices:
              [Y2Storage::Planned::Partition.new("/boot", Y2Storage::Filesystems::Type::EXT2)]
          )
        end

        it "does not propose another /boot" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "and there is no planned device for /boot" do
        context "but something in the devicegraph is choosen as /boot" do
          let(:scenario) { "lvm_with_boot" }

          it "does not propose another /boot" do
            expect(checker.needed_partitions).to be_empty
          end
        end

        context "and there is no /boot in the devicegraph" do
          it "proposes to create a new /boot partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(mount_point: "/boot", reuse?: false)
            )
          end
        end
      end
    end

    context "when a PReP partition is needed" do
      let(:architecture) { :ppc }
      let(:scenario) { "trivial" }
      let(:power_nv) { false }

      context "and a suitable PReP is already in the list of planned partitions" do
        subject(:checker) do
          planned_partition = Y2Storage::Planned::Partition.new(nil)
          planned_partition.partition_id = Y2Storage::PartitionId::PREP
          planned_partition.size = 8.MiB
          described_class.new(
            fake_devicegraph,
            planned_devices: [planned_partition]
          )
        end

        it "does not propose another PReP" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "and there is no PReP in the list of planned devices" do
        context "and there are no PReP partitions in the target disk" do
          it "proposes to create a PReP partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(partition_id: Y2Storage::PartitionId::PREP)
            )
          end
        end

        context "but there is already a suitable PReP partition in the disk" do
          let(:scenario) { "prep" }

          it "does not propose another PReP" do
            expect(checker.needed_partitions).to be_empty
          end
        end
      end
    end

    context "when /boot/zipl is needed" do
      # Default values to ensure the partition is needed
      let(:architecture) { :s390 }

      context "and /boot/zipl is already in the list of planned partitions" do
        subject(:checker) do
          described_class.new(
            fake_devicegraph,
            planned_devices:
              [Y2Storage::Planned::Partition.new("/boot/zipl", Y2Storage::Filesystems::Type::EXT2)]
          )
        end


        it "does not propose another /boot/zipl" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "and there is no planned device for /boot/zipl" do
        context "but something in the devicegraph is choosen as /boot/zipl" do
          let(:scenario) { "zipl" }

          it "does not propose another /boot/zipl" do
            expect(checker.needed_partitions).to be_empty
          end
        end

        context "and there is no /boot/zipl in the devicegraph" do
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
      let(:scenario) { "trivial_lvm" }

      context "and some GRUB is already in the list of planned partitions" do
        subject(:checker) do
          planned_partition = Y2Storage::Planned::Partition.new(nil)
          planned_partition.partition_id = Y2Storage::PartitionId::BIOS_BOOT
          planned_partition.size = 8.MiB
          described_class.new(
            fake_devicegraph,
            planned_devices: [planned_partition]
          )
        end

        it "does not propose another GRUB partition" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "and there are no GRUB partitions in the list of planned devices" do
        context "and there are no GRUB partitions in the target disk" do
          it "proposes to create a GRUB partition" do
            expect(checker.needed_partitions).to include(
              an_object_having_attributes(partition_id: Y2Storage::PartitionId::BIOS_BOOT)
            )
          end
        end

        context "but there is already a GRUB partition in the disk" do
          let(:scenario) { "lvm_with_bios_boot" }
          it "does not propose another GRUB partition" do
            expect(checker.needed_partitions).to be_empty
          end
        end
      end
    end
  end
end
