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

  let(:space_settings) do
    Y2Storage::ProposalSpaceSettings.new.tap do |settings|
      settings.strategy = :bigger_resize
      settings.actions = settings_actions
    end
  end
  let(:settings_actions) { [] }
  let(:analyzer) { Y2Storage::DiskAnalyzer.new(fake_devicegraph) }
  let(:delete) { Y2Storage::SpaceActions::Delete }
  let(:resize) { Y2Storage::SpaceActions::Resize }
  let(:disks) { ["/dev/sda"] }

  subject(:maker) { described_class.new(analyzer, space_settings) }

  describe "#prepare_devicegraph" do
    let(:scenario) { "complex-lvm-encrypt" }

    context "if no device is set as :force_delete " do
      let(:settings_actions) { [delete.new("/dev/sda1"), delete.new("/dev/sda2")] }

      it "does not delete any partition" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions.size).to eq fake_devicegraph.partitions.size
      end
    end

    # Mandatory delete for disks should be ignored, actions only make sense for partitions and LVs
    context "if :force_delete is specified for a disk that contains partitions" do
      let(:settings_actions) { [delete.new("/dev/sda", mandatory: true)] }

      it "does not delete any partition" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions.size).to eq fake_devicegraph.partitions.size
      end
    end

    context "if :force_delete is specified for several partitions" do
      let(:settings_actions) { { "/dev/sda2" => :force_delete, "/dev/sde1" => :force_delete } }
      let(:settings_actions) do
        [delete.new("/dev/sda2", mandatory: true), delete.new("/dev/sde1", mandatory: true)]
      end

      it "does not delete partitions out of SpaceMaker#default_disks" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions.map(&:name)).to include "/dev/sde1"
      end

      it "deletes affected partitions within the candidate devices" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions.map(&:name)).to_not include "/dev/sda2"
      end
    end

    # Mandatory delete for disks should be ignored, actions only make sense for partitions and LVs
    context "if :force_delete is specified for a directly formatted disk (no partition table)" do
      let(:scenario) { "multipath-formatted.xml" }

      let(:settings_actions) do
        [delete.new("/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1", mandatory: true)]
      end

      let(:disks) { ["/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1"] }

      it "does not modify the content of the disk" do
        original_filesystems = fake_devicegraph.filesystems
        expect(original_filesystems.size).to eq 1

        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        filesystems = result.filesystems
        expect(filesystems.size).to eq 1
        device = filesystems.first.blk_devices.first
        expect(device.name).to eq "/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1"
      end
    end

    context "when deleting a btrfs partition that is part of a multidevice btrfs" do
      let(:scenario) { "btrfs-multidevice-over-partitions.xml" }
      let(:settings_actions) { [delete.new("/dev/sda1", mandatory: true)] }

      it "deletes the partitions explicitly mentioned in the settings" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions.map(&:name)).to_not include "/dev/sda1"
      end

      it "does not delete other partitions constituting the same btrfs" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions.map(&:name)).to include "/dev/sda2", "/dev/sda3", "/dev/sdb2"
      end
    end

    context "when deleting a partition that is part of a raid" do
      let(:scenario) { "raid0-over-partitions.xml" }
      let(:settings_actions) { [delete.new("/dev/sda1", mandatory: true)] }

      it "deletes the partitions explicitly mentioned in the settings" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions.map(&:name)).to_not include "/dev/sda1"
      end

      it "does not delete other partitions constituting the same raid" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions.map(&:name)).to include "/dev/sda2", "/dev/sda3", "/dev/sdb2"
      end
    end

    context "when deleting a partition that is part of a lvm volume group" do
      let(:scenario) { "lvm-over-partitions.xml" }
      let(:settings_actions) { [delete.new("/dev/sda1", mandatory: true)] }

      it "deletes the partitions explicitly mentioned in the settings" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions.map(&:name)).to_not include "/dev/sda1"
      end

      it "does not delete other partitions constituting the same volume group" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions.map(&:name)).to include "/dev/sda2", "/dev/sda3", "/dev/sdb2"
      end
    end

    context "if there is a resize action with a max that is smaller than the partition size" do
      using Y2Storage::Refinements::SizeCasts

      let(:scenario) { "irst-windows-linux-gpt" }
      let(:settings_actions) do
        [resize.new("/dev/sda2"), resize.new("/dev/sda3", max_size: 200.GiB)]
      end

      let(:resize_info) do
        instance_double("ResizeInfo", resize_ok?: true, min_size: 100.GiB, max_size: 800.GiB)
      end

      before do
        allow_any_instance_of(Y2Storage::Partition)
          .to receive(:detect_resize_info).and_return(resize_info)
      end

      it "resizes the partition to the specified max if possible" do
        result = maker.prepare_devicegraph(fake_devicegraph, disks)
        expect(result.partitions).to include(
          an_object_having_attributes(filesystem_label: "other", size: 200.GiB)
        )
      end
    end
  end

  describe "#provide_space" do
    using Y2Storage::Refinements::SizeCasts

    let(:volumes) { [vol1] }

    context "if the only disk is not big enough" do
      let(:scenario) { "empty_hard_disk_mbr_50GiB" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 60.GiB) }

      it "raises an Error exception" do
        expect { maker.provide_space(fake_devicegraph, disks, volumes) }
          .to raise_error Y2Storage::Error
      end
    end

    context "if the only disk has no partition table and is not used in any other way" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 40.GiB) }

      it "does not modify the disk" do
        result = maker.provide_space(fake_devicegraph, disks, volumes)
        disk = result[:devicegraph].disks.first
        expect(disk.partition_table).to be_nil
      end

      it "assumes a (future) GPT partition table" do
        gpt_size = 1.MiB
        # The final 16.5 KiB are reserved by GPT
        gpt_final_space = 16.5.KiB

        result = maker.provide_space(fake_devicegraph, disks, volumes)
        space = result[:partitions_distribution].spaces.first
        expect(space.disk_size).to eq(50.GiB - gpt_size - gpt_final_space)
      end
    end

    context "if the only disk is directly used as PV (no partition table)" do
      let(:scenario) { "lvm-disk-as-pv.xml" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 5.GiB) }

      it "empties the disk deleting the LVM VG" do
        expect(fake_devicegraph.lvm_vgs.size).to eq 1

        result = maker.provide_space(fake_devicegraph, disks, volumes)
        disk = result[:devicegraph].disks.first
        expect(disk.has_children?).to eq false
        expect(result[:devicegraph].lvm_vgs).to be_empty
      end

      it "assumes a (future) GPT partition table" do
        gpt_size = 1.MiB
        # The final 16.5 KiB are reserved by GPT
        gpt_final_space = 16.5.KiB

        result = maker.provide_space(fake_devicegraph, disks, volumes)
        space = result[:partitions_distribution].spaces.first
        expect(space.disk_size).to eq(space.disk.size - gpt_size - gpt_final_space)
      end
    end

    context "if the only available device is directly formatted (no partition table)" do
      let(:scenario) { "multipath-formatted.xml" }
      let(:vol1) { planned_vol(mount_point: "/1", type: :ext4, min: 5.GiB) }

      let(:disks) { ["/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1"] }

      it "empties the device deleting the filesystem" do
        expect(fake_devicegraph.filesystems.size).to eq 1

        result = maker.provide_space(fake_devicegraph, disks, volumes)
        disk = result[:devicegraph].disk_devices.first
        expect(disk.has_children?).to eq false
        expect(result[:devicegraph].filesystems).to be_empty
      end

      it "assumes a (future) GPT partition table" do
        gpt_size = 1.MiB
        # The final 16.5 KiB are reserved by GPT
        gpt_final_space = 16.5.KiB

        result = maker.provide_space(fake_devicegraph, disks, volumes)
        space = result[:partitions_distribution].spaces.first
        expect(space.disk_size).to eq(space.disk.size - gpt_size - gpt_final_space)
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
          [
            resize.new("/dev/sda2"), resize.new("/dev/sda3"),
            delete.new("/dev/sda5"), delete.new("/dev/sda6")
          ]
        end

        context "and resizing one partition is enough" do
          let(:volumes) { [vol1] }

          it "resizes the more 'productive' partition" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            expect(result[:devicegraph].partitions).to include(
              an_object_having_attributes(filesystem_label: "windows", size: 210.GiB)
            )
          end

          it "does not delete any partition" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            expect(result[:devicegraph].partitions.map(&:name)).to contain_exactly(
              "/dev/sda1", "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sda5"
            )
          end

          it "suggests a distribution using the freed space" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            distribution = result[:partitions_distribution]
            expect(distribution.spaces.size).to eq 1
            expect(distribution.spaces.first.partitions).to eq volumes
          end
        end

        context "and resizing one partition is not enough because more space is needed" do
          let(:volumes) { [vol1, vol2] }

          it "resizes subsequent partitions" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            expect(result[:devicegraph].partitions).to include(
              an_object_having_attributes(filesystem_label: "windows", size: 100.GiB),
              an_object_having_attributes(filesystem_label: "other", size: 110.GiB)
            )
          end

          it "does not delete any partition" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            expect(result[:devicegraph].partitions.map(&:name)).to contain_exactly(
              "/dev/sda1", "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sda5"
            )
          end

          it "suggests a distribution using the freed space" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            distribution = result[:partitions_distribution]
            expect(distribution.spaces.size).to eq 2
            expect(distribution.spaces.flat_map(&:partitions)).to contain_exactly(*volumes)
          end
        end

        context "and resizing one partition is not enough because the action is limited" do
          let(:volumes) { [vol1] }

          let(:settings_actions) do
            [
              resize.new("/dev/sda2", min_size: 250.GiB), resize.new("/dev/sda3"),
              delete.new("/dev/sda5"), delete.new("/dev/sda6")
            ]
          end

          it "resizes the more 'productive' partition taking restrictions into account" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            expect(result[:devicegraph].partitions).to include(
              an_object_having_attributes(filesystem_label: "windows", size: 360.GiB),
              an_object_having_attributes(filesystem_label: "other", size: 110.GiB)
            )
          end

          it "does not delete any partition" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            expect(result[:devicegraph].partitions.map(&:name)).to contain_exactly(
              "/dev/sda1", "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sda5"
            )
          end

          it "suggests a distribution using the freed space" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            distribution = result[:partitions_distribution]
            expect(distribution.spaces.size).to eq 1
            expect(distribution.spaces.first.partitions).to eq volumes
          end
        end

        context "and resizing all the allowed partitions is not enough" do
          let(:volumes) { [vol1, vol2, vol3] }

          it "resizes all allowed partitions to its minimum size" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            expect(result[:devicegraph].partitions).to include(
              an_object_having_attributes(filesystem_label: "windows", size: 100.GiB),
              an_object_having_attributes(filesystem_label: "other", size: 100.GiB)
            )
          end

          it "deletes partitions starting with the one closer to the end of the disk" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            expect(result[:devicegraph].partitions.map(&:name)).to contain_exactly(
              "/dev/sda1", "/dev/sda2", "/dev/sda3", "/dev/sda4"
            )
          end

          it "suggests a distribution using the freed space" do
            result = maker.provide_space(fake_devicegraph, disks, volumes)
            distribution = result[:partitions_distribution]
            expect(distribution.spaces.size).to eq 3
            expect(distribution.spaces.flat_map(&:partitions)).to contain_exactly(*volumes)
          end

          context "if resize operations are limited" do
            let(:settings_actions) do
              [
                resize.new("/dev/sda2", min_size: 150.GiB),
                resize.new("/dev/sda3", min_size: 110.GiB),
                delete.new("/dev/sda5"), delete.new("/dev/sda6")
              ]
            end

            it "resizes all allowed partitions their specified limits" do
              result = maker.provide_space(fake_devicegraph, disks, volumes)
              expect(result[:devicegraph].partitions).to include(
                an_object_having_attributes(filesystem_label: "windows", size: 150.GiB),
                an_object_having_attributes(filesystem_label: "other", size: 110.GiB)
              )
            end
          end
        end
      end
    end
  end
end
