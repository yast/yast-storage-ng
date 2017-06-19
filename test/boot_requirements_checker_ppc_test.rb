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
  describe "#needed_partitions in a PPC64 system" do
    using Y2Storage::Refinements::SizeCasts

    include_context "boot requirements"

    let(:prep_id) { Y2Storage::PartitionId::PREP }
    let(:architecture) { :ppc }
    let(:boot_ptable_type) { :msdos }

    before do
      allow(storage_arch).to receive(:ppc_power_nv?).and_return(power_nv)
      allow(dev_sda).to receive(:grub_partitions).and_return []
      allow(dev_sda).to receive(:prep_partitions).and_return prep_partitions
    end

    context "in a non-PowerNV system (KVM/LPAR)" do
      let(:power_nv) { false }

      context "with a partitions-based proposal" do
        let(:use_lvm) { false }

        context "if there are no PReP partitions in the target disk" do
          let(:prep_partitions) { [] }

          it "requires only a PReP partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: nil, partition_id: prep_id)
            )
          end
        end

        context "if there is already a PReP partition in the disk" do
          let(:prep_partitions) { [partition_double("/dev/sda1")] }

          it "does not require any particular volume" do
            expect(checker.needed_partitions).to be_empty
          end
        end
      end

      context "with a LVM-based proposal" do
        let(:use_lvm) { true }

        context "if there are no PReP partitions in the target disk" do
          let(:prep_partitions) { [] }

          it "requires /boot and PReP partitions" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot"),
              an_object_having_attributes(mount_point: nil, partition_id: prep_id)
            )
          end
        end

        context "if there is already a PReP partition in the disk" do
          let(:prep_partitions) { [partition_double("/dev/sda1")] }

          it "requires only a /boot partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot")
            )
          end
        end
      end

      context "with an encrypted proposal" do
        let(:use_lvm) { false }
        let(:use_encryption) { true }

        context "if there are no PReP partitions in the target disk" do
          let(:prep_partitions) { [] }

          it "requires /boot and PReP partitions" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot"),
              an_object_having_attributes(mount_point: nil, partition_id: prep_id)
            )
          end
        end

        context "if there is already a PReP partition in the disk" do
          let(:prep_partitions) { [partition_double("/dev/sda1")] }

          it "requires only a /boot partition" do
            expect(checker.needed_partitions).to contain_exactly(
              an_object_having_attributes(mount_point: "/boot")
            )
          end
        end
      end
    end

    context "in bare metal (PowerNV)" do
      let(:power_nv) { true }
      let(:prep_partitions) { [] }

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
            an_object_having_attributes(mount_point: "/boot")
          )
        end
      end

      context "with an encrypted proposal" do
        let(:use_lvm) { false }
        let(:use_encryption) { true }

        it "requires only a /boot partition" do
          expect(checker.needed_partitions).to contain_exactly(
            an_object_having_attributes(mount_point: "/boot")
          )
        end
      end
    end

    context "when proposing a boot partition" do
      let(:boot_part) { find_vol("/boot", checker.needed_partitions(target)) }
      # Default values to ensure the presence of a /boot partition
      let(:use_lvm) { true }
      let(:boot_ptable_type) { :msdos }
      let(:prep_partitions) { [] }
      let(:power_nv) { true }

      include_examples "proposed boot partition"
    end

    context "when proposing a PReP partition" do
      let(:prep_part) { find_vol(nil, checker.needed_partitions(target)) }
      # Default values to ensure the presence of a PReP partition
      let(:use_lvm) { false }
      let(:power_nv) { false }
      let(:prep_partitions) { [] }

      include_examples "proposed PReP partition"
    end
  end
end
