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
  describe "#needed_partitions in a PPC64 system" do
    using Y2Storage::Refinements::SizeCasts

    include_context "boot requirements"

    let(:architecture) { :ppc }
    let(:prep_id) { Y2Storage::PartitionId::PREP }

    context "in a non-PowerNV system (KVM/LPAR)" do
      let(:power_nv) { false }

      context "with a partitions-based proposal" do
        context "if there are no PReP partitions in the target disk" do
          let(:scenario) { "trivial" }
          it "requires only a PReP partition (to allocate Grub2)" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: nil, partition_id: prep_id)
            )
          end

          it "does not require a separate /boot partition (Grub2 can handle this setup)" do
            expect(checker.needed_partitions.map(&:mount_point)).to_not include "/boot"
          end
        end

        context "if there is already a PReP partition in the disk" do
          let(:scenario) { "prep" }

          it "does not require any partition (PReP will be reused and Grub2 can handle this setup)" do
            expect(checker.needed_partitions).to be_empty
          end
        end
      end

      context "with a LVM-based proposal" do
        context "if there are no PReP partitions in the target disk" do
          let(:scenario) { "trivial_lvm" }

          it "requires only a PReP partition (to allocate Grub2)" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: nil, partition_id: prep_id)
            )
          end

          it "does not require a separate /boot partition (Grub2 can handle this setup)" do
            expect(checker.needed_partitions.map(&:mount_point)).to_not include "/boot"
          end
        end

        context "if there is already a PReP partition in the disk" do
          let(:scenario) { "prep_lvm" }

          it "does not require any partition (PReP will be reused and Grub2 can handle this setup)" do
            expect(checker.needed_partitions).to be_empty
          end
        end
      end

      context "with an encrypted proposal" do
        context "if there are no PReP partitions in the target disk" do
          let(:scenario) { "trivial_encrypted" }

          it "requires only a PReP partition (to allocate Grub2)" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: nil, partition_id: prep_id)
            )
          end

          it "does not require a separate /boot partition (Grub2 can handle this setup)" do
            expect(checker.needed_partitions.map(&:mount_point)).to_not include "/boot"
          end
        end

        context "if there is already a PReP partition in the disk" do
          let(:scenario) { "prep_encrypted" }

          it "does not require any partition (PReP will be reused and Grub2 can handle this setup)" do
            expect(checker.needed_partitions).to be_empty
          end
        end
      end
    end

    context "in bare metal (PowerNV)" do
      let(:power_nv) { true }

      context "with a partitions-based proposal" do
        let(:scenario) { "trivial" }

        it "does not require any booting partition (no Grub stage1, PPC firmware parses grub2.cfg)" do
          expect(checker.needed_partitions).to be_empty
        end
      end

      context "with a LVM-based proposal" do
        let(:scenario) { "trivial_lvm" }

        it "does not require a PReP partition (no Grub stage1, PPC firmware parses grub2.cfg)" do
          expect(checker.needed_partitions).to_not include(
            an_object_having_attributes(mount_point: nil, partition_id: prep_id)
          )
        end

        it "requires only a /boot partition (for the PPC firmware to load the kernel)" do
          expect(checker.needed_partitions).to contain_exactly(
            an_object_having_attributes(mount_point: "/boot")
          )
        end
      end

      context "with an encrypted proposal" do
        let(:scenario) { "trivial_encrypted" }

        it "does not require a PReP partition (no Grub stage1, PPC firmware parses grub2.cfg)" do
          expect(checker.needed_partitions).to_not include(
            an_object_having_attributes(mount_point: nil, partition_id: prep_id)
          )
        end

        it "requires only a /boot partition (for the PPC firmware to load the kernel)" do
          expect(checker.needed_partitions).to contain_exactly(
            an_object_having_attributes(mount_point: "/boot")
          )
        end
      end
    end
  end
end
