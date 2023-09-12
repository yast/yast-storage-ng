#!/usr/bin/env rspec
# Copyright (c) [2023] SUSE LLC
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

describe Y2Storage::Proposal::SpaceMaker do
  # Partition from fake_devicegraph, fetched by name
  def probed_partition(name)
    fake_devicegraph.partitions.detect { |p| p.name == name }
  end

  before do
    fake_scenario(scenario)
  end

  let(:settings) do
    settings = Y2Storage::ProposalSettings.new_for_current_product
    settings.candidate_devices = ["/dev/sda"]
    settings.root_device = "/dev/sda"
    settings.space_settings.strategy = :bigger_resize
    settings.space_settings.actions = settings_actions
    settings
  end
  let(:settings_actions) { {} }
  let(:analyzer) { Y2Storage::DiskAnalyzer.new(fake_devicegraph) }

  subject(:maker) { described_class.new(analyzer, settings) }

  describe "#prepare_devicegraph" do
    let(:scenario) { "complex-lvm-encrypt" }

    context "if no device is set as :force_delete " do
      let(:settings_actions) { { "/dev/sda1" => :delete, "/dev/sda2" => :delete } }

      it "does not delete any partition" do
        result = maker.prepare_devicegraph(fake_devicegraph)
        expect(result.partitions.size).to eq fake_devicegraph.partitions.size
      end
    end

    context "if :force_delete is specified for a disk that contains partitions" do
      let(:settings_actions) { { "/dev/sda" => :force_delete } }

      it "does not delete any partition" do
        result = maker.prepare_devicegraph(fake_devicegraph)
        expect(result.partitions.size).to eq fake_devicegraph.partitions.size
      end
    end

    context "if :force_delete is specified for several partitions" do
      let(:settings_actions) { { "/dev/sda2" => :force_delete, "/dev/sde1" => :force_delete } }

      it "does not delete partitions out of SpaceMaker#candidate_devices" do
        result = maker.prepare_devicegraph(fake_devicegraph)
        expect(result.partitions.map(&:name)).to include "/dev/sde1"
      end

      it "deletes affected partitions within the candidate devices" do
        result = maker.prepare_devicegraph(fake_devicegraph)
        expect(result.partitions.map(&:name)).to_not include "/dev/sda2"
      end
    end

    context "if :force_delete is specified for a directly formatted disk (no partition table)" do
      let(:scenario) { "multipath-formatted.xml" }

      let(:settings_actions) { { "/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1" => :force_delete } }
      before do
        settings.candidate_devices = ["/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1"]
        settings.root_device = "/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1"
      end

      it "empties the device deleting the filesystem" do
        expect(fake_devicegraph.filesystems.size).to eq 1

        result = maker.prepare_devicegraph(fake_devicegraph)
        disk = result.disk_devices.first
        expect(disk.has_children?).to eq false
        expect(result.filesystems).to be_empty
      end
    end

    context "when deleting a btrfs partition that is part of a multidevice btrfs" do
      let(:scenario) { "btrfs-multidevice-over-partitions.xml" }
      let(:settings_actions) { { "/dev/sda1" => :force_delete } }

      it "deletes the partitions explicitly mentioned in the settings" do
        result = maker.prepare_devicegraph(fake_devicegraph)
        expect(result.partitions.map(&:name)).to_not include "/dev/sda1"
      end

      it "does not delete other partitions constituting the same btrfs" do
        result = maker.prepare_devicegraph(fake_devicegraph)
        expect(result.partitions.map(&:name)).to include "/dev/sda2", "/dev/sda3", "/dev/sdb2"
      end
    end

    context "when deleting a partition that is part of a raid" do
      let(:scenario) { "raid0-over-partitions.xml" }
      let(:settings_actions) { { "/dev/sda1" => :force_delete } }

      it "deletes the partitions explicitly mentioned in the settings" do
        result = maker.prepare_devicegraph(fake_devicegraph)
        expect(result.partitions.map(&:name)).to_not include "/dev/sda1"
      end

      it "does not delete other partitions constituting the same raid" do
        result = maker.prepare_devicegraph(fake_devicegraph)
        expect(result.partitions.map(&:name)).to include "/dev/sda2", "/dev/sda3", "/dev/sdb2"
      end
    end

    context "when deleting a partition that is part of a lvm volume group" do
      let(:scenario) { "lvm-over-partitions.xml" }
      let(:settings_actions) { { "/dev/sda1" => :force_delete } }

      it "deletes the partitions explicitly mentioned in the settings" do
        result = maker.prepare_devicegraph(fake_devicegraph)
        expect(result.partitions.map(&:name)).to_not include "/dev/sda1"
      end

      it "does not delete other partitions constituting the same volume group" do
        result = maker.prepare_devicegraph(fake_devicegraph)
        expect(result.partitions.map(&:name)).to include "/dev/sda2", "/dev/sda3", "/dev/sdb2"
      end
    end
  end

  describe "#provide_space" do
    using Y2Storage::Refinements::SizeCasts

    let(:volumes) { [vol1] }
    let(:lvm_helper) { Y2Storage::Proposal::LvmHelper.new([], settings) }

    context "if the only disk is not big enough" do
      let(:scenario) { "empty_hard_disk_mbr_50GiB" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 60.GiB) }

      it "raises an Error exception" do
        expect { maker.provide_space(fake_devicegraph, volumes, lvm_helper) }
          .to raise_error Y2Storage::Error
      end
    end

    context "if the only disk has no partition table and is not used in any other way" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 40.GiB) }

      it "does not modify the disk" do
        result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
        disk = result[:devicegraph].disks.first
        expect(disk.partition_table).to be_nil
      end

      it "assumes a (future) GPT partition table" do
        gpt_size = 1.MiB
        # The final 16.5 KiB are reserved by GPT
        gpt_final_space = 16.5.KiB

        result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
        space = result[:partitions_distribution].spaces.first
        expect(space.disk_size).to eq(50.GiB - gpt_size - gpt_final_space)
      end
    end

    context "if the only disk is directly used as PV (no partition table)" do
      let(:scenario) { "lvm-disk-as-pv.xml" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 5.GiB) }

      context "and the disk is not mentioned in the settings" do
        let(:settings_actions) { { "/dev/sda1" => :delete } }

        it "raises an Error exception" do
          expect { maker.provide_space(fake_devicegraph, volumes, lvm_helper) }
            .to raise_error Y2Storage::Error
        end
      end

      context "and the disk is marked to be deleted" do
        let(:settings_actions) { { "/dev/sda" => :delete } }

        it "empties the disk deleting the LVM VG" do
          expect(fake_devicegraph.lvm_vgs.size).to eq 1

          result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
          disk = result[:devicegraph].disks.first
          expect(disk.has_children?).to eq false
          expect(result[:devicegraph].lvm_vgs).to be_empty
        end

        it "assumes a (future) GPT partition table" do
          gpt_size = 1.MiB
          # The final 16.5 KiB are reserved by GPT
          gpt_final_space = 16.5.KiB

          result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
          space = result[:partitions_distribution].spaces.first
          expect(space.disk_size).to eq(space.disk.size - gpt_size - gpt_final_space)
        end
      end
    end

    context "if the only available device is directly formatted (no partition table)" do
      let(:scenario) { "multipath-formatted.xml" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 5.GiB) }

      before do
        settings.candidate_devices = ["/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1"]
        settings.root_device = "/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1"
      end

      context "and the device is not mentioned in the settings" do
        let(:settings_actions) { {} }

        it "raises an Error exception" do
          expect { maker.provide_space(fake_devicegraph, volumes, lvm_helper) }
            .to raise_error Y2Storage::Error
        end
      end

      context "and the disk is marked to be deleted" do
        let(:settings_actions) { { "/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1" => :delete } }

        it "empties the device deleting the filesystem" do
          expect(fake_devicegraph.filesystems.size).to eq 1

          result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
          disk = result[:devicegraph].disk_devices.first
          expect(disk.has_children?).to eq false
          expect(result[:devicegraph].filesystems).to be_empty
        end

        it "assumes a (future) GPT partition table" do
          gpt_size = 1.MiB
          # The final 16.5 KiB are reserved by GPT
          gpt_final_space = 16.5.KiB

          result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
          space = result[:partitions_distribution].spaces.first
          expect(space.disk_size).to eq(space.disk.size - gpt_size - gpt_final_space)
        end
      end
    end

    context "with one disk containing several partitions" do
      let(:scenario) { "irst-windows-linux-gpt" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 150.GiB) }
      let(:vol2) { planned_vol(mount_point: "/2", type: :ext4, min: 150.GiB) }
      let(:vol3) { planned_vol(mount_point: "/3", type: :ext4, min: 150.GiB) }
      let(:resize_info) do
        instance_double("ResizeInfo", resize_ok?: true, min_size: 100.GiB, max_size: 800.GiB)
      end

      before do
        allow_any_instance_of(Y2Storage::Partition)
          .to receive(:detect_resize_info).and_return(resize_info)
      end

      context "if resizing some partitions and deleting others is allowed" do
        let(:settings_actions) do
          {
            "/dev/sda2" => :resize, "/dev/sda3" => :resize,
            "/dev/sda5" => :delete, "/dev/sda6" => :delete
          }
        end

        context "and resizing one partition is enough" do
          let(:volumes) { [vol1] }

          it "resizes the more 'productive' partition" do
            result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
            expect(result[:devicegraph].partitions).to include(
              an_object_having_attributes(filesystem_label: "windows", size: 210.GiB)
            )
          end

          it "does not delete any partition" do
            result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
            expect(result[:devicegraph].partitions.map(&:name)).to contain_exactly(
              "/dev/sda1", "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sda5"
            )
          end

          it "suggests a distribution using the freed space" do
            result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
            distribution = result[:partitions_distribution]
            expect(distribution.spaces.size).to eq 1
            expect(distribution.spaces.first.partitions).to eq volumes
          end
        end

        context "and resizing one partition is not enough" do
          let(:volumes) { [vol1, vol2] }

          it "resizes subsequent partitions" do
            result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
            expect(result[:devicegraph].partitions).to include(
              an_object_having_attributes(filesystem_label: "windows", size: 100.GiB),
              an_object_having_attributes(filesystem_label: "other", size: 110.GiB)
            )
          end

          it "does not delete any partition" do
            result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
            expect(result[:devicegraph].partitions.map(&:name)).to contain_exactly(
              "/dev/sda1", "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sda5"
            )
          end

          it "suggests a distribution using the freed space" do
            result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
            distribution = result[:partitions_distribution]
            expect(distribution.spaces.size).to eq 2
            expect(distribution.spaces.flat_map(&:partitions)).to contain_exactly(*volumes)
          end
        end

        context "and resizing all the allowed partitions is not enough" do
          let(:volumes) { [vol1, vol2, vol3] }

          it "resizes all allowed partitions to its minimum size" do
            result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
            expect(result[:devicegraph].partitions).to include(
              an_object_having_attributes(filesystem_label: "windows", size: 100.GiB),
              an_object_having_attributes(filesystem_label: "other", size: 100.GiB)
            )
          end

          it "deletes partitions starting with the one closer to the end of the disk" do
            result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
            expect(result[:devicegraph].partitions.map(&:name)).to contain_exactly(
              "/dev/sda1", "/dev/sda2", "/dev/sda3", "/dev/sda4"
            )
          end

          it "suggests a distribution using the freed space" do
            result = maker.provide_space(fake_devicegraph, volumes, lvm_helper)
            distribution = result[:partitions_distribution]
            expect(distribution.spaces.size).to eq 3
            expect(distribution.spaces.flat_map(&:partitions)).to contain_exactly(*volumes)
          end
        end
      end
    end
  end
end
