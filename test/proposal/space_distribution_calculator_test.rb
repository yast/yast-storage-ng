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

describe Y2Storage::Proposal::SpaceDistributionCalculator do
  let(:lvm_volumes) { Y2Storage::PlannedVolumesList.new }
  let(:lvm_helper) { Y2Storage::Proposal::LvmHelper.new(lvm_volumes) }

  subject(:calculator) { described_class.new(lvm_helper) }

  describe "#best_distribution" do
    using Y2Storage::Refinements::SizeCasts
    using Y2Storage::Refinements::DevicegraphLists

    before do
      fake_scenario(scenario)
    end

    let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, desired: 1.GiB, max: 3.GiB, weight: 1) }
    let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, desired: 2.GiB, max: 3.GiB, weight: 1) }
    let(:volumes) { Y2Storage::PlannedVolumesList.new([vol1, vol2, vol3]) }
    let(:spaces) { fake_devicegraph.free_disk_spaces.to_a }

    subject(:distribution) { calculator.best_distribution(volumes, spaces) }

    context "when the only available space is in an extended partition" do
      let(:scenario) { "space_22_extended" }

      context "if the space is not big enough" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 30.GiB, max: 30.GiB) }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end

      context "if the space is big enough" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 3.GiB, max: 3.GiB) }

        it "allocates all the volumes in the available space" do
          spaces = distribution.spaces
          expect(spaces.size).to eq 1
          expect(spaces.first.volumes).to contain_exactly(vol1, vol2, vol3)
        end

        it "sets the partition type to :logical" do
          space = distribution.spaces.first
          expect(space.partition_type).to eq :logical
        end

        it "plans all the partitions as logical" do
          space = distribution.spaces.first
          expect(space.num_logical).to eq space.volumes.size
        end
      end
    end

    context "when the only available space is unassigned (ms-dos partition table)" do
      let(:scenario) { "space_22" }

      context "if the space is not big enough" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 30.GiB, max: 30.GiB) }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end

      context "if the space is big enough" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 19.GiB - 2.MiB) }

        it "allocates all the volumes in the available space" do
          spaces = distribution.spaces
          expect(spaces.size).to eq 1
          expect(spaces.first.volumes).to contain_exactly(vol1, vol2, vol3)
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
        end

        context "if the space does not have extra room for the EBRs" do
          let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 19.GiB) }

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
            let(:volumes) { Y2Storage::PlannedVolumesList.new([vol1, vol2]) }

            it "sets partition_type to primary" do
              spaces = distribution.spaces
              expect(spaces.first.partition_type).to eq :primary
            end

            it "plans no logical partitions" do
              space = distribution.spaces.first
              expect(space.num_logical).to eq 0
            end
          end
        end
      end
    end

    context "when there are several free spaces" do
      context "if the sum of all spaces is not big enough" do
        let(:scenario) { "spaces_5_6_8_10" }
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 30.GiB, max: 30.GiB) }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end

      context "if all the volumes fit in one space" do
        let(:scenario) { "spaces_5_6_8_10" }
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 3.GiB, max: 3.GiB) }

        it "allocates all the partitions in the same space" do
          spaces = distribution.spaces
          expect(spaces.size).to eq 1
          expect(spaces.first.volumes).to contain_exactly(vol1, vol2, vol3)
        end

        it "uses the biggest space it can fill completely" do
          space = distribution.spaces.first
          expect(space.disk_size).to eq 8.GiB
        end
      end

      context "if no single space is big enough" do
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 3.GiB, max: 3.GiB) }

        context "and it's possible to avoid gaps" do
          let(:scenario) { "spaces_5_3" }

          it "completely fills all the used spaces" do
            expect(distribution.gaps_count).to eq 0
          end
        end

        context "and it's not possible to fill all the spaces" do
          let(:scenario) { "spaces_4_4" }

          it "creates the smallest possible gap" do
            expect(distribution.gaps_total_disk_size).to eq 1021.MiB
          end
        end

        context "and all the spaces are inside an extended partition" do
          let(:scenario) { "spaces_5_3_extended" }

          it "plans all partitions as logical" do
            types = distribution.spaces.map { |s| s.partition_type }
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
                types = distribution.spaces.map { |s| s.partition_type }
                expect(types).to eq [:primary, :primary]
              end

              it "plans all partitions as primary" do
                logical = distribution.spaces.map { |s| s.num_logical }
                expect(logical).to eq [0, 0]
              end
            end
          end

          context "and there is no extended partition" do
            let(:scenario) { "spaces_5_3" }
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
              let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 2.GiB) }
              let(:vol4) { planned_vol(mount_point: "/4", type: :ext4, desired: 2.GiB - 2.MiB) }
              let(:volumes) { Y2Storage::PlannedVolumesList.new([vol1, vol2, vol3, vol4]) }

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
                let(:vol4) { planned_vol(mount_point: "/4", type: :ext4, desired: 2.GiB) }

                it "returns no distribution (nil)" do
                  expect(distribution).to be_nil
                end
              end
            end

            context "and the number of partitions is below the primary limit" do
              let(:vol2) do
                planned_vol(mount_point: "/2", type: :ext4, desired: 3.GiB - 1.MiB, max: 5.GiB)
              end
              let(:volumes) { Y2Storage::PlannedVolumesList.new([vol2, vol3]) }

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
    end

    context "if disk restrictions apply to some volume" do
      before do
        # Avoid rounding problems
        vol1.desired = 1.GiB - 2.MiB
      end

      let(:vol3) do
        planned_vol(mount_point: "/3", type: :ext4, desired: 3.GiB - 1.MiB, max: 3.GiB, disk: "/dev/sda")
      end

      context "if a proper distribution is possible" do
        let(:scenario) { "spaces_5_1_two_disks" }

        it "honors the disk restrictions" do
          sda = distribution.spaces.detect { |s| s.disk_name == "/dev/sda" }
          expect(sda.volumes).to include vol3
        end

        it "completely fills all the used spaces" do
          expect(distribution.gaps_count).to eq 0
        end
      end

      context "if the only way to avoid gaps is breaking the disk restrictions" do
        let(:scenario) { "spaces_3_8_two_disks" }

        it "honors the disk restrictions" do
          sda = distribution.spaces.detect { |s| s.disk_name == "/dev/sda" }
          expect(sda.volumes).to include vol3
        end

        it "creates the smallest possible gap" do
          expect(distribution.gaps_total_disk_size).to eq(2.GiB - 1.MiB)
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

      let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 1.GiB, max: 30.GiB, weight: 2) }
      let(:lvm_volumes) { Y2Storage::PlannedVolumesList.new([lvm_vol]) }
      let(:lvm_vol) { planned_vol(desired: lvm_size, max: lvm_max) }
      let(:lvm_max) { Y2Storage::DiskSize.unlimited }

      let(:pv_vols) do
        volumes = distribution.spaces.map { |sp| sp.volumes.to_a }
        volumes.map { |vols| vols.select(&:lvm_pv?) }.flatten
      end

      context "if the sum of all the spaces is not big enough" do
        let(:lvm_size) { 30.GiB }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end

      context "if one space can host the volumes and the LVM space" do
        let(:lvm_size) { 2.GiB }

        it "allocates everything in the same space" do
          spaces = distribution.spaces
          expect(spaces.size).to eq 1
          expect(spaces.first.volumes).to contain_exactly(
            vol1,
            vol2,
            vol3,
            an_object_with_fields(partition_id: Storage::ID_LVM)
          )
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
          useful_min_sizes = pv_vols.map { |v| lvm_helper.useful_pv_space(v.min_disk_size) }
          expect(useful_min_sizes.reduce(:+)).to eq lvm_size
        end

        it "sets desired_disk_size for all PVs to sum lvm_size" do
          useful_desired_sizes = pv_vols.map { |v| lvm_helper.useful_pv_space(v.desired_disk_size) }
          expect(useful_desired_sizes.reduce(:+)).to eq lvm_size
        end

        it "sets max_disk_size for all PVs to sum lvm_max" do
          useful_max_sizes = pv_vols.map { |v| lvm_helper.useful_pv_space(v.max_disk_size) }
          expect(useful_max_sizes.reduce(:+)).to eq lvm_max
        end

        context "if there are other volumes in the same space" do
          let(:space) { distribution.spaces.detect { |s| s.volumes.size > 1 } }

          it "sets the weight of the PV according to the other volumes" do
            pv_vol = space.volumes.detect(&:lvm_pv?)
            total_weight = space.volumes.map(&:weight).reduce(:+)
            expect(pv_vol.weight).to eq(total_weight / 2.0)
          end
        end

        context "if the PV is alone in the disk space" do
          let(:space) { distribution.spaces.detect { |s| s.volumes.size == 1 } }

          it "sets the weight of the PV to one" do
            pv_vol = space.volumes.detect(&:lvm_pv?)
            expect(pv_vol.weight).to eq 1
          end
        end
      end

      context "when dealing with both LVM and logical partitions overhead" do
        let(:scenario) { "logical-lvm-rounding" }
        let(:lvm_size) { 5.GiB }
        let(:lvm_max) { 5.GiB }
        let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, desired: 2.GiB, max: 2.GiB) }
        let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, desired: 1.GiB, max: 1.GiB) }
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 1.GiB, max: 1.GiB) }

        # This test was added because we figured out that the original algorithm
        # to create physical volume was leading to discard some valid solutions
        it "returns the best possible solution (minimal gap)" do
          expect(distribution.gaps_total_disk_size).to be <= (4.GiB - 9.MiB)
          expect(distribution.gaps_count).to eq 1
        end
      end
    end
  end
end
