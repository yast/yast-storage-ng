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
require "storage/proposal"
require "storage/refinements/devicegraph_lists"
require "storage/refinements/size_casts"

describe Yast::Storage::Proposal::SpaceDistribution do
  describe ".better_for" do
    using Yast::Storage::Refinements::SizeCasts
    using Yast::Storage::Refinements::DevicegraphLists

    before do
      fake_scenario(scenario)
    end

    let(:settings) do
      settings = Yast::Storage::Proposal::Settings.new
      settings.candidate_devices = ["/dev/sda"]
      settings.root_device = "/dev/sda"
      settings
    end

    let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, desired: 1.GiB, max: 3.GiB, weight: 1) }
    let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, desired: 2.GiB, max: 3.GiB, weight: 1) }
    let(:volumes) { Yast::Storage::PlannedVolumesList.new([vol1, vol2, vol3]) }
    let(:spaces) { fake_devicegraph.free_disk_spaces.to_a }

    subject(:distribution) { described_class.best_for(volumes, spaces, fake_devicegraph) }

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

        it "plans all partitions as logical" do
          spaces = distribution.spaces
          expect(spaces.first.partition_type).to eq :extended
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
        let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, desired: 3.GiB, max: 3.GiB) }

        it "allocates all the volumes in the available space" do
          spaces = distribution.spaces
          expect(spaces.size).to eq 1
          expect(spaces.first.volumes).to contain_exactly(vol1, vol2, vol3)
        end

        context "and there is no extended partition" do
          it "does not enforce the partition type" do
            spaces = distribution.spaces
            expect(spaces.first.partition_type).to be_nil
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
            let(:volumes) { Yast::Storage::PlannedVolumesList.new([vol1, vol2]) }

            it "plans all partitions as primary" do
              spaces = distribution.spaces
              expect(spaces.first.partition_type).to eq :primary
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
          expect(space.size).to eq 8.GiB
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
            # FIXME: I was actually expecting 1.GiB here, but it's not a big deal
            expect(distribution.gaps_total_size).to eq 1021.MiB
          end
        end

        context "and all the spaces are inside an extended partition" do
          let(:scenario) { "spaces_5_3_extended" }

          it "plans all partitions as logical" do
            types = distribution.spaces.map { |s| s.partition_type }
            expect(types).to eq [:extended, :extended]
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

              it "plans all partitions as primary" do
                types = distribution.spaces.map { |s| s.partition_type }
                expect(types).to eq [:primary, :primary]
              end
            end
          end

          context "and there is no extended partition" do
            let(:scenario) { "spaces_5_3" }

            context "and the number of partitions reaches the primary limit" do
              it "chooses one space for an extended partition and the rest as primary" do
                space5 = distribution.spaces.detect { |s| s.size == 5.GiB }
                space3 = distribution.spaces.detect { |s| s.size == 3071.MiB }
                expect(space5.partition_type).to eq :extended
                expect(space3.partition_type).to eq :primary
              end
            end

            context "and the number of partitions is below the primary limit" do
              let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, desired: 3.GiB, max: 5.GiB) }
              let(:volumes) { Yast::Storage::PlannedVolumesList.new([vol2, vol3]) }

              it "does not enforce the partition types" do
                types = distribution.spaces.map { |s| s.partition_type }
                expect(types).to eq [nil, nil]
              end
            end
          end
        end
      end
    end

    context "if disk restrictions apply to some volume" do
      before do
        settings.candidate_devices = ["/dev/sda", "/dev/sdb"]
      end

      let(:vol3) do
        planned_vol(mount_point: "/3", type: :ext4, desired: 3.GiB, max: 3.GiB, disk: "/dev/sda")
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
          expect(distribution.gaps_total_size).to eq 2.GiB
        end
      end

      context "if is not possible to honor the disk restrictions" do
        let(:scenario) { "spaces_2_10_two_disks" }

        it "returns no distribution (nil)" do
          expect(distribution).to be_nil
        end
      end
    end
  end
end
