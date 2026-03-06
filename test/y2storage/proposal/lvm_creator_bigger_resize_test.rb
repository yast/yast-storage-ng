#!/usr/bin/env rspec

# Copyright (c) [2026] SUSE LLC
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
require "y2storage"

describe Y2Storage::Proposal::LvmCreator do
  using Y2Storage::Refinements::SizeCasts

  subject(:creator) { described_class.new(fake_devicegraph, space_settings) }

  before { fake_scenario(scenario) }

  let(:scenario) { "lvm-new-pvs" }
  let(:space_settings) do
    Y2Storage::ProposalSpaceSettings.new.tap do |settings|
      settings.strategy = :bigger_resize
      settings.actions = settings_actions
    end
  end
  let(:settings_actions) { [] }
  let(:delete) { Y2Storage::SpaceActions::Delete }
  let(:resize) { Y2Storage::SpaceActions::Resize }

  describe "#create_volumes" do
    before { vg.reuse_name = reused_vg.vg_name }

    let(:reused_vg) { fake_devicegraph.lvm_vgs.first }
    let(:vg) { planned_vg(lvs: volumes) }
    let(:pv_partitions) { [] }
    let(:ext4) { Y2Storage::Filesystems::Type::EXT4 }

    context "if there is enough space for the new LVs" do
      let(:volumes) do
        [
          planned_lv(mount_point: "/1", type: :ext4, logical_volume_name: "one", min: 5.GiB),
          planned_lv(mount_point: "/2", type: :ext4, logical_volume_name: "two", min: 5.GiB)
        ]
      end

      context "and there are no mandatory actions" do
        let(:settings_actions) do
          [
            delete.new("/dev/vg0/lv1", mandatory: false),
            resize.new("/dev/vg0/lv1", min_size: 0.GiB)
          ]
        end

        it "creates the new LVs" do
          devicegraph = creator.create_volumes(vg, pv_partitions).devicegraph
          vg = devicegraph.lvm_vgs.first
          expect(vg.lvm_lvs.map(&:lv_name)).to include "one", "two"
        end

        it "does not modify the pre-existing LVs" do
          devicegraph = creator.create_volumes(vg, pv_partitions).devicegraph
          lvs = devicegraph.lvm_vgs.first.lvm_lvs
          expect(lvs).to include(
            an_object_having_attributes(lv_name: "lv1", size: 10.GiB),
            an_object_having_attributes(lv_name: "lv2", size: 8.GiB)
          )
        end
      end

      context "and there are mandatory actions to delete logical volumes" do
        let(:settings_actions) { [delete.new("/dev/vg0/lv1", mandatory: true)] }

        it "deletes the designated pre-existing LVs and creates the new ones" do
          devicegraph = creator.create_volumes(vg, pv_partitions).devicegraph
          lvs = devicegraph.lvm_vgs.first.lvm_lvs
          expect(lvs.map(&:lv_name)).to contain_exactly "lv2", "one", "two"
        end
      end

      context "and there are mandatory actions to resize logical volumes" do
        let(:settings_actions) { [resize.new("/dev/vg0/lv1", max_size: 8.GiB)] }

        let(:resize_info) do
          instance_double("ResizeInfo", resize_ok?: true, min_size: 1.GiB, max_size: 30.GiB)
        end

        before do
          allow_any_instance_of(Y2Storage::LvmLv)
            .to receive(:detect_resize_info).and_return(resize_info)
        end

        it "creates the new LVs" do
          devicegraph = creator.create_volumes(vg, pv_partitions).devicegraph
          vg = devicegraph.lvm_vgs.first
          expect(vg.lvm_lvs.map(&:lv_name)).to include "one", "two"
        end

        it "resizes the pre-existing LVs according to the action" do
          devicegraph = creator.create_volumes(vg, pv_partitions).devicegraph
          lvs = devicegraph.lvm_vgs.first.lvm_lvs
          expect(lvs).to include(
            an_object_having_attributes(lv_name: "lv1", size: 8.GiB),
            an_object_having_attributes(lv_name: "lv2", size: 8.GiB)
          )
        end
      end
    end

    context "if there is no enough space for the new LVs" do
      let(:volumes) do
        [
          planned_lv(mount_point: "/1", type: :ext4, logical_volume_name: "one", min: 10.GiB),
          planned_lv(mount_point: "/2", type: :ext4, logical_volume_name: "two", min: 5.GiB)
        ]
      end

      context "and no actions are allowed" do
        it "raises a NoDiskSpace exception" do
          expect { creator.create_volumes(vg, pv_partitions) }
            .to raise_error Y2Storage::NoDiskSpaceError
        end
      end

      context "and delete and resizing are allowed" do
        let(:settings_actions) do
          [
            delete.new("/dev/vg0/lv1", mandatory: false),
            resize.new("/dev/vg0/lv1", min_size: 0.GiB)
          ]
        end

        before do
          allow_any_instance_of(Y2Storage::LvmLv)
            .to receive(:detect_resize_info).and_return(resize_info)
        end

        context "and resizing is enough" do
          let(:resize_info) do
            instance_double("ResizeInfo", resize_ok?: true, min_size: 1.GiB, max_size: 30.GiB)
          end

          it "creates the new LVs" do
            devicegraph = creator.create_volumes(vg, pv_partitions).devicegraph
            vg = devicegraph.lvm_vgs.first
            expect(vg.lvm_lvs.map(&:lv_name)).to include "one", "two"
          end

          it "resizes the pre-existing LVs as needed" do
            devicegraph = creator.create_volumes(vg, pv_partitions).devicegraph
            lvs = devicegraph.lvm_vgs.first.lvm_lvs
            expect(lvs).to include(
              an_object_having_attributes(lv_name: "lv1", size: 7.GiB - 4.MiB),
              an_object_having_attributes(lv_name: "lv2", size: 8.GiB)
            )
          end
        end

        context "and resizing is not enough" do
          let(:resize_info) do
            instance_double("ResizeInfo", resize_ok?: true, min_size: 8.GiB, max_size: 30.GiB)
          end

          it "deletes the pre-existing LVs as needed to create the new ones" do
            devicegraph = creator.create_volumes(vg, pv_partitions).devicegraph
            lvs = devicegraph.lvm_vgs.first.lvm_lvs
            expect(lvs.map(&:lv_name)).to contain_exactly "lv2", "one", "two"
          end
        end
      end
    end

    context "when creating new thin volumes in an existing pool" do
      let(:scenario) { "lvm_with_nested_thin_lvs.xml" }
      let(:reused_vg) { fake_devicegraph.find_by_name("/dev/vg_a") }
      let(:reused_pool) { fake_devicegraph.find_by_name("/dev/vg_a/lvt_01") }

      let(:volumes) { [planned_lv(logical_volume_name: reused_pool.lv_name)] }
      let(:thin_volumes) do
        [
          planned_lv(
            mount_point: "/1", type: :ext4, logical_volume_name: "one", min: 100.GiB,
            lv_type: Y2Storage::LvType::THIN
          ),
          planned_lv(
            mount_point: "/2", type: :ext4, logical_volume_name: "two", min: 100.GiB,
            lv_type: Y2Storage::LvType::THIN
          )
        ]
      end

      let(:settings_actions) do
        [
          delete.new("/dev/vg_a/lv_01", mandatory: false),
          resize.new("/dev/vg_a/lv_01", min_size: 0.GiB),
          delete.new("/dev/vg_a/lv_02", mandatory: false),
          resize.new("/dev/vg_a/lv_02", min_size: 0.GiB),
          delete.new("/dev/vg_a/tv_01", mandatory: false),
          resize.new("/dev/vg_a/tv_01", min_size: 0.GiB)
        ]
      end

      before do
        volumes.first.assign_reuse(reused_pool)
        thin_volumes.each { |v| volumes.first.add_thin_lv(v) }
        allow_any_instance_of(Y2Storage::LvmLv)
          .to receive(:detect_resize_info).and_return(resize_info)
      end

      let(:resize_info) do
        instance_double("ResizeInfo", resize_ok?: true, min_size: 1.GiB, max_size: 30.GiB)
      end

      it "does not delete or resize any other logical volume" do
        initial_lvs = reused_vg.lvm_lvs
        initial_thin_lvs = reused_pool.lvm_lvs

        devicegraph = creator.create_volumes(vg, pv_partitions).devicegraph
        vg = devicegraph.find_by_name("/dev/vg_a")
        pool = devicegraph.find_by_name("/dev/vg_a/lvt_01")

        expect(vg.lvm_lvs.size).to eq initial_lvs.size
        expect(Y2Storage::DiskSize.sum(vg.lvm_lvs.map(&:size)))
          .to eq Y2Storage::DiskSize.sum(initial_lvs.map(&:size))

        expect(pool.lvm_lvs.size).to eq initial_thin_lvs.size + 2
        # The LvmCreator uses the total size of the thin pool as maximum size for new thin vols
        expect(Y2Storage::DiskSize.sum(pool.lvm_lvs.map(&:size)))
          .to eq Y2Storage::DiskSize.sum(initial_thin_lvs.map(&:size)) + 20.GiB
      end
    end
  end
end
