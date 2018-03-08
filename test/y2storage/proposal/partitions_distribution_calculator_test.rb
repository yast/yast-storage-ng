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

require_relative "../spec_helper"
require "storage"
require "y2storage"

describe Y2Storage::Proposal::PartitionsDistributionCalculator do
  let(:lvm_volumes) { [] }
  let(:lvm_helper) { Y2Storage::Proposal::LvmHelper.new(lvm_volumes, encryption_password: enc_password) }
  let(:enc_password) { nil }

  subject(:calculator) { described_class.new(lvm_helper) }

  describe "#best_distribution" do
    using Y2Storage::Refinements::SizeCasts

    before do
      fake_scenario(scenario)
    end

    let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 1.GiB, max: 3.GiB, weight: 1) }
    let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, min: 2.GiB, max: 3.GiB, weight: 1) }
    let(:volumes) { [vol1, vol2, vol3] }
    let(:spaces) { fake_devicegraph.free_spaces }

    subject(:distribution) { calculator.best_distribution(volumes, spaces) }

    context "when the only available space is in an extended partition" do
      let(:scenario) { "space_22_extended" }

      context "if the space is not big enough" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 30.GiB, max: 30.GiB) }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end

      context "if the space is big enough" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 3.GiB, max: 3.GiB) }

        it "uses align grain to properly allocate partitions" do
          expect(spaces.first).to receive(:align_grain).at_least(:once)
          subject
        end

        it "allocates all the volumes in the available space" do
          spaces = distribution.spaces
          expect(spaces.size).to eq 1
          expect(spaces.first.partitions).to contain_exactly(vol1, vol2, vol3)
        end

        it "sets the partition type to :logical" do
          space = distribution.spaces.first
          expect(space.partition_type).to eq :logical
        end

        it "plans all the partitions as logical" do
          space = distribution.spaces.first
          expect(space.num_logical).to eq space.partitions.size
        end

        context "if any of the planned partitions must be primary" do
          before { vol3.primary = true }

          it "returns no distribution (nil)" do
            expect(distribution).to be_nil
          end
        end
      end
    end

    context "when the only available space is unassigned (ms-dos partition table)" do
      let(:scenario) { "space_22" }

      context "if the space is not big enough" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 30.GiB, max: 30.GiB) }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end

      context "if the space is big enough" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 19.GiB - 2.MiB) }

        it "allocates all the volumes in the available space" do
          spaces = distribution.spaces
          expect(spaces.size).to eq 1
          expect(spaces.first.partitions).to contain_exactly(vol1, vol2, vol3)
        end

        it "keeps the order of the planned partitions" do
          space = distribution.spaces.first
          expect(space.partitions).to eq [vol1, vol2, vol3]
        end

        context "and there is no extended partition" do
          it "does not set the partition type" do
            space = distribution.spaces.first
            expect(space.partition_type).to be_nil
          end

          it "plans the surplus partitions as logical" do
            space = distribution.spaces.first
            expect(space.num_logical).to eq 2
          end

          it "keeps the order of the planned partitions" do
            space = distribution.spaces.first
            expect(space.partitions).to eq [vol1, vol2, vol3]
          end

          context "if some planned partition must be primary" do
            context "and it is in the area assigned to primary partitions" do
              before { vol1.primary = true }

              it "returns a valid distribution" do
                expect(distribution).to_not be_nil
              end

              it "keeps the order of the planned partitions" do
                space = distribution.spaces.first
                expect(space.partitions).to eq [vol1, vol2, vol3]
              end
            end

            context "and it is in the area assigned to logical partitions" do
              before { vol2.primary = true }

              it "returns no distribution (nil)" do
                expect(distribution).to be_nil
              end
            end
          end
        end

        context "if the space does not have extra room for the EBRs" do
          let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 19.GiB) }

          it "returns no distribution (nil)" do
            expect(distribution).to be_nil
          end
        end

        context "and there is already a extended partition" do
          let(:scenario) { "space_22_used_extended" }

          context "and the number of partitions exceeds the primary limit" do
            it "returns no distribution (nil)" do
              expect(distribution).to be_nil
            end
          end

          context "and there are not too many primary partitions already" do
            let(:volumes) { [vol1, vol2] }

            it "sets partition_type to primary" do
              spaces = distribution.spaces
              expect(spaces.first.partition_type).to eq :primary
            end

            it "plans no logical partitions" do
              space = distribution.spaces.first
              expect(space.num_logical).to eq 0
            end

            it "keeps the order of the planned partitions" do
              space = distribution.spaces.first
              expect(space.partitions).to eq [vol1, vol2]
            end

            context "even if the last partition is compulsorily primary" do
              before { vol2.primary = true }

              it "keeps the order of the planned partitions" do
                space = distribution.spaces.first
                expect(space.partitions).to eq [vol1, vol2]
              end
            end
          end
        end
      end
    end

    context "when there are several free spaces" do
      let(:scenario) { "spaces_5_3" }

      context "if the sum of all spaces is not big enough" do
        let(:scenario) { "spaces_5_6_8_10" }
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 30.GiB, max: 30.GiB) }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end

      context "if only one distribution ensures that not gaps will be introduced" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 3.GiB, max: 5.GiB - 1.MiB) }

        before { vol1.max = 2.GiB }

        it "returns that best distribution" do
          expect(distribution.gaps_count).to eq 0
          expect(distribution.gaps_total_size).to eq(Y2Storage::DiskSize.zero)
          expect(spaces.size).to eq(2)
        end
      end

      context "if one distribution creates smaller gaps than the others" do
        let(:scenario) { "spaces_4_4" }
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 3.GiB, max: 3.GiB) }

        it "returns that best distribution" do
          expect(distribution.gaps_total_size).to eq 1021.MiB
        end
      end

      context "if there are several distributions that wouldn't introduce gaps" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 3.GiB, max: 3.GiB) }

        context "but one has better distributed weights (lower #weight_space_deviation)" do
          it "returns that best distribution" do
            # The expected distribution is: vol1 and vol3 to the first space
            grouping = distribution.spaces.map(&:partitions)
            expect(grouping).to eq [[vol1, vol3], [vol2]]
          end
        end

        context "with an equivalent distribution of weights (#weight_space_deviation)" do
          let(:vol1) do
            planned_vol(mount_point: "/1", type: :ext4, min: 1.GiB, max: 1.GiB, weight: 0)
          end

          let(:vol2) do
            planned_vol(mount_point: "/2", type: :ext4, min: 2.GiB, max: 2.GiB, weight: 0)
          end

          let(:volumes) { [vol1, vol2] }

          it "returns the distribution in which the new partitions are more grouped" do
            # The expected distribution is: everything in the 3 GiB space
            expect(distribution.spaces.size).to eq 1
            expect(distribution.gaps_total_size).to eq(5119.MiB)
          end
        end

        context "and all the spaces are inside an extended partition" do
          let(:scenario) { "spaces_5_3_extended" }

          it "plans all partitions as logical" do
            types = distribution.spaces.map(&:partition_type)
            expect(types).to eq [:logical, :logical]
          end
        end

        context "and the spaces are unassigned (ms-dos partition table)" do
          context "and there is already an extended partition" do
            context "and the number of partitions exceeds the primary limit" do
              let(:scenario) { "spaces_5_3_used_extended_alt" }

              it "returns no distribution (nil)" do
                expect(distribution).to be_nil
              end
            end

            context "and there are not too many primary partitions already" do
              let(:scenario) { "spaces_5_3_used_extended" }

              it "sets the primary partition type for all the spaces" do
                types = distribution.spaces.map(&:partition_type)
                expect(types).to eq [:primary, :primary]
              end

              it "plans all partitions as primary" do
                logical = distribution.spaces.map(&:num_logical)
                expect(logical).to eq [0, 0]
              end
            end
          end

          context "and there is no extended partition" do
            let(:space5) { distribution.spaces.detect { |s| s.disk_size == 5.GiB } }
            let(:space3) { distribution.spaces.detect { |s| s.disk_size == (3.GiB - 1.MiB) } }

            context "and the number of partitions equals the primary limit" do
              it "does not set any enforced partition_type" do
                expect(space5.partition_type).to be_nil
                expect(space3.partition_type).to be_nil
              end

              it "plans all partitions in all spaces as primary" do
                expect(space5.num_logical).to eq 0
                expect(space3.num_logical).to eq 0
              end
            end

            context "and the number of partitions exceeds the primary limit" do
              let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 2.GiB) }
              let(:vol4) { planned_vol(mount_point: "/4", type: :ext4, min: 2.GiB - 2.MiB) }
              let(:volumes) { [vol1, vol2, vol3, vol4] }

              it "does not set any enforced partition_type" do
                expect(space5.partition_type).to be_nil
                expect(space3.partition_type).to be_nil
              end

              it "chooses one space to contain all the logical partitions" do
                expect(space5.num_logical).to eq 2
              end

              it "ensures other spaces only contain primary partitions" do
                expect(space3.num_logical).to eq 0
              end

              context "and there is no room for the EBRs" do
                let(:vol4) { planned_vol(mount_point: "/4", type: :ext4, min: 2.GiB) }

                it "returns no distribution (nil)" do
                  expect(distribution).to be_nil
                end
              end
            end

            context "and the number of partitions is below the primary limit" do
              let(:vol2) do
                planned_vol(mount_point: "/2", type: :ext4, min: 3.GiB - 1.MiB, max: 5.GiB)
              end
              let(:volumes) { [vol2, vol3] }

              it "does not set any enforced partition_type" do
                expect(space5.partition_type).to be_nil
                expect(space3.partition_type).to be_nil
              end

              it "plans all partitions in all spaces as primary" do
                expect(space5.num_logical).to eq 0
                expect(space3.num_logical).to eq 0
              end
            end
          end
        end
      end

      context "if there are free spaces that belong to an implicit partition table" do
        let(:scenario) { "several-dasds" }

        let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 1.GiB, max: 1.GiB, weight: 1) }
        let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, min: 1.GiB, max: 1.GiB, weight: 1) }
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 1.GiB, max: 1.GiB, weight: 1) }
        let(:volumes) { [vol1, vol2, vol3] }

        it "only assigns one partition to the free space of an implicit partition table" do
          spaces_in_implitic = distribution.spaces.select do |space|
            space.disk_space.in_implicit_partition_table?
          end

          spaces_in_implitic.each { |s| expect(s.partitions.size).to eq(1) }
        end
      end
    end

    context "when the only free space belongs to an implicit partition table" do
      let(:scenario) { "several-dasds" }

      let(:device) { fake_devicegraph.find_by_name(device_name) }

      let(:device_name) { "/dev/dasda" }

      let(:spaces) { device.free_spaces }

      context "and only one volume needs to be created" do
        let(:volumes) { [vol1] }

        it "allocates the volume in the available space" do
          expect(distribution.spaces.first.partitions).to contain_exactly(vol1)
        end
      end

      context "and several volumes needs to be created" do
        let(:volumes) { [vol1, vol2] }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end
    end

    context "if disk restrictions apply to some volume" do
      before do
        # Avoid rounding problems
        vol1.min_size = 1.GiB - 2.MiB
      end

      let(:vol3) do
        planned_vol(mount_point: "/3", type: :ext4, min: 3.GiB - 1.MiB, max: 3.GiB, disk: "/dev/sda")
      end

      context "if a proper distribution is possible" do
        let(:scenario) { "spaces_5_1_two_disks" }

        it "honors the disk restrictions" do
          sda = distribution.spaces.detect { |s| s.disk_name == "/dev/sda" }
          expect(sda.partitions).to include vol3
        end

        it "completely fills all the used spaces" do
          expect(distribution.gaps_count).to eq 0
        end
      end

      context "if the only way to avoid gaps is breaking the disk restrictions" do
        let(:scenario) { "spaces_3_8_two_disks" }

        it "honors the disk restrictions" do
          sda = distribution.spaces.detect { |s| s.disk_name == "/dev/sda" }
          expect(sda.partitions).to include vol3
        end

        it "creates the smallest possible gap" do
          expect(distribution.gaps_total_size).to eq(2.GiB - 1.MiB)
        end
      end

      context "if is not possible to honor the disk restrictions" do
        let(:scenario) { "spaces_2_10_two_disks" }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end
    end

    context "when asking for extra LVM space" do
      let(:scenario) { "spaces_5_6_8_10" }

      let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 1.GiB, max: 30.GiB, weight: 2) }
      let(:lvm_volumes) { [lvm_vol] }
      let(:lvm_vol) { planned_lv(min: lvm_size, max: lvm_max) }
      let(:lvm_max) { Y2Storage::DiskSize.unlimited }

      let(:pv_vols) do
        volumes = distribution.spaces.map(&:partitions)
        volumes.map { |vols| vols.select(&:lvm_pv?) }.flatten
      end

      context "if the sum of all the spaces is not big enough" do
        let(:lvm_size) { 30.GiB }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end

      context "if only one space can host all the LVM space" do
        let(:lvm_size) { 9.GiB }

        it "adds one PV in that space" do
          expect(pv_vols.size).to eq 1
        end
      end

      context "if no single space is big enough" do
        let(:lvm_size) { 11.GiB }

        it "adds several PVs" do
          expect(pv_vols.size).to eq 2
        end
      end

      context "when creating PVs" do
        let(:lvm_size) { 11.GiB }
        let(:lvm_max) { 20.GiB }

        it "sets min_disk_size for all PVs to sum lvm_size" do
          useful_min_sizes = pv_vols.map { |v| lvm_helper.useful_pv_space(v.min_size) }
          expect(useful_min_sizes.reduce(:+)).to eq lvm_size
        end

        it "sets min_disk_size for all PVs to sum lvm_size" do
          useful_min_sizes = pv_vols.map { |v| lvm_helper.useful_pv_space(v.min_size) }
          expect(useful_min_sizes.reduce(:+)).to eq lvm_size
        end

        it "sets max_disk_size for all PVs to sum lvm_max" do
          useful_max_sizes = pv_vols.map { |v| lvm_helper.useful_pv_space(v.max_size) }
          expect(useful_max_sizes.reduce(:+)).to eq lvm_max
        end

        context "if encryption is being used" do
          let(:enc_password) { "DontLookAtMe" }

          it "sets #encrypted_password for all the PVs" do
            expect(pv_vols.map(&:encryption_password)).to all(eq "DontLookAtMe")
          end
        end

        context "if there are other volumes in the same space" do
          # Let's enforce the creation of more PVs to ensure there is one space
          # with one PV and one planned volume
          let(:lvm_size) { 18.GiB }
          let(:space) do
            distribution.spaces.detect do |space|
              space.partitions.size > 1 && space.partitions.any?(&:lvm_pv?)
            end
          end

          it "sets the weight of the PV according to the other volumes" do
            pv_vol = space.partitions.detect(&:lvm_pv?)
            total_weight = space.total_weight
            expect(pv_vol.weight).to eq(total_weight / 2.0)
          end
        end

        context "if the PV is alone in the disk space" do
          let(:space) do
            distribution.spaces.detect do |space|
              space.partitions.size == 1 && space.partitions.first.lvm_pv?
            end
          end

          it "sets the weight of the PV to one" do
            pv_vol = space.partitions.first
            expect(pv_vol.weight).to eq 1
          end
        end
      end

      context "when dealing with both LVM and logical partitions overhead" do
        let(:scenario) { "logical-lvm-rounding" }
        let(:lvm_size) { 5.GiB }
        let(:lvm_max) { 5.GiB }
        let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 2.GiB, max: 2.GiB) }
        let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, min: 1.GiB, max: 1.GiB) }
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 1.GiB, max: 1.GiB) }

        # This test was added because we figured out that the original algorithm
        # to create physical volume was leading to discard some valid solutions
        it "returns the best possible solution (minimal gap)" do
          expect(distribution.gaps_total_size).to be <= (4.GiB - 9.MiB)
          expect(distribution.gaps_count).to eq 1
        end
      end
    end
  end
end
