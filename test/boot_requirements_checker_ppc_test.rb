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
require_relative "support/proposed_boot_partition_examples"
require_relative "support/boot_requirements_context"
require "storage/proposal"
require "storage/boot_requirements_checker"
require "storage/refinements/size_casts"

describe Yast::Storage::BootRequirementsChecker do
  describe "#needed_partitions in a PPC64 system" do
    using Yast::Storage::Refinements::SizeCasts

    include_context "boot requirements"

    let(:prep_id) { ::Storage::ID_PPC_PREP }
    let(:architecture) { :ppc }

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

      include_examples "proposed boot partition"
    end

    context "when proposing a PReP partition" do
      let(:prep_part) { find_vol(nil, checker.needed_partitions) }
      # Default values to ensure the max num of proposed volumes
      let(:prep_partitions) { {} }
      let(:use_lvm) { true }
      let(:power_nv) { false }

      it "requires it to be between 256KiB and 8MiB, despite the alignment" do
        expect(prep_part.min).to eq 256.KiB
        expect(prep_part.max).to eq 8.MiB
        expect(prep_part.align).to eq :keep_size
      end

      it "recommends it to be 1 MiB" do
        expect(prep_part.desired).to eq 1.MiB
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
