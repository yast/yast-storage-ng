#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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

require_relative "../../test_helper"
require "y2partitioner/device_graphs"
require "y2partitioner/actions/controllers/btrfs_devices"

describe Y2Partitioner::Actions::Controllers::BtrfsDevices do
  using Y2Storage::Refinements::SizeCasts

  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(filesystem: filesystem) }

  let(:filesystem) { nil }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:scenario) { "mixed_disks" }

  describe "#metadata_raid_level" do
    before do
      subject.metadata_raid_level = raid1
    end

    let(:raid1) { Y2Storage::BtrfsRaidLevel::RAID1 }

    it "returns the selected metadata RAID level" do
      expect(subject.metadata_raid_level).to eq(raid1)
    end
  end

  describe "#metadata_raid_level=" do
    let(:filesystem) { device.filesystem }

    let(:device_name) { "/dev/sdc" }

    let(:raid1) { Y2Storage::BtrfsRaidLevel::RAID1 }

    before do
      device.remove_descendants
      device.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
    end

    it "sets the metadata RAID level" do
      subject.metadata_raid_level = raid1

      expect(subject.metadata_raid_level).to eq(raid1)
      expect(filesystem.metadata_raid_level).to eq(raid1)
    end
  end

  describe "#data_raid_level" do
    before do
      subject.data_raid_level = raid1
    end

    let(:raid1) { Y2Storage::BtrfsRaidLevel::RAID1 }

    it "returns the selected data RAID level" do
      expect(subject.data_raid_level).to eq(raid1)
    end
  end

  describe "#data_raid_level=" do
    let(:filesystem) { device.filesystem }

    let(:device_name) { "/dev/sdc" }

    let(:raid1) { Y2Storage::BtrfsRaidLevel::RAID1 }

    before do
      device.remove_descendants
      device.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
    end

    it "sets the data RAID level" do
      subject.data_raid_level = raid1

      expect(subject.data_raid_level).to eq(raid1)
      expect(filesystem.data_raid_level).to eq(raid1)
    end
  end

  describe "#raid_levels" do
    it "returns a list of BtrfsRaidLevel" do
      expect(subject.raid_levels).to all(be_a(Y2Storage::BtrfsRaidLevel))
    end

    it "does not include RAID5" do
      expect(subject.raid_levels).to_not include(Y2Storage::BtrfsRaidLevel::RAID5)
    end

    it "does not include RAID6" do
      expect(subject.raid_levels).to_not include(Y2Storage::BtrfsRaidLevel::RAID6)
    end
  end

  describe "#allowed_raid_levels" do
    let(:filesystem) { device.filesystem }

    let(:device_name) { "/dev/sdc" }

    before do
      device.remove_descendants
      device.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
    end

    shared_examples "raid levels" do
      let(:default_level) { Y2Storage::BtrfsRaidLevel::DEFAULT }
      let(:single_level) { Y2Storage::BtrfsRaidLevel::SINGLE }
      let(:dup_level) { Y2Storage::BtrfsRaidLevel::DUP }
      let(:raid0) { Y2Storage::BtrfsRaidLevel::RAID0 }
      let(:raid1) { Y2Storage::BtrfsRaidLevel::RAID1 }
      let(:raid5) { Y2Storage::BtrfsRaidLevel::RAID5 }
      let(:raid6) { Y2Storage::BtrfsRaidLevel::RAID6 }
      let(:raid10) { Y2Storage::BtrfsRaidLevel::RAID10 }

      it "returns a list of BtrfsRaidLevel" do
        expect(subject.allowed_raid_levels(data)).to all(be_a(Y2Storage::BtrfsRaidLevel))
      end

      context "when it is a single-device Btrfs" do
        it "contains DEFAULT, SINGLE and DUP" do
          expect(subject.allowed_raid_levels(data))
            .to contain_exactly(default_level, single_level, dup_level)
        end
      end

      context "when it is a multi-device Btrfs" do
        context "and the filesystem has up to 3 devices" do
          before do
            sdb1 = current_graph.find_by_name("/dev/sdb1")
            sdb2 = current_graph.find_by_name("/dev/sdb2")

            sdb1.remove_descendants
            sdb2.remove_descendants

            filesystem.add_device(sdb1)
            filesystem.add_device(sdb2)
          end

          it "contains DEFAULT, SINGLE, RAID0 and RAID1" do
            expect(subject.filesystem.blk_devices.size).to eq(3)

            expect(subject.allowed_raid_levels(data))
              .to contain_exactly(default_level, single_level, raid0, raid1)
          end
        end

        context "and the filesystem has more than 3 devices" do
          before do
            sdb1 = current_graph.find_by_name("/dev/sdb1")
            sdb2 = current_graph.find_by_name("/dev/sdb2")
            sdb3 = current_graph.find_by_name("/dev/sdb3")

            sdb1.remove_descendants
            sdb2.remove_descendants
            sdb3.remove_descendants

            filesystem.add_device(sdb1)
            filesystem.add_device(sdb2)
            filesystem.add_device(sdb3)
          end

          it "contains DEFAULT, SINGLE, RAID0, RAID1 and RAID10" do
            expect(subject.filesystem.blk_devices.size).to eq(4)

            expect(subject.allowed_raid_levels(data))
              .to contain_exactly(default_level, single_level, raid0, raid1, raid10)
          end
        end
      end
    end

    context "for metadata" do
      let(:data) { :metadata }

      include_examples "raid levels"
    end

    context "for data" do
      let(:data) { :data }

      include_examples "raid levels"
    end
  end

  describe "#available_devices" do
    it "returns an list of block devices" do
      expect(subject.available_devices).to be_a(Array)
      expect(subject.available_devices).to all(be_a(Y2Storage::BlkDevice))
    end

    context "when a device already belongs to the Btrfs" do
      let(:scenario) { "mixed_disks_btrfs" }

      let(:device_name) { "/dev/sdb3" }

      let(:filesystem) { device.filesystem }

      it "does not include the device" do
        expect(subject.available_devices).to_not include(device)
      end
    end

    context "when a device is formatted" do
      context "and the filesystem is not mounted" do
        let(:device_name) { "/dev/sdb3" }

        it "includes the device" do
          expect(subject.available_devices).to include(device)
        end
      end

      context "and the filesystem is mounted" do
        let(:device_name) { "/dev/sdb2" }

        it "does not include the device" do
          expect(subject.available_devices).to_not include(device)
        end
      end
    end

    context "when a device is not formatted" do
      context "and the device is an extended partition" do
        let(:device_name) { "/dev/sdb4" }

        it "does not include the device" do
          expect(subject.available_devices).to_not include(device)
        end
      end

      context "and the device has zero-size" do
        let(:scenario) { "zero-size_disk" }

        let(:device_name) { "/dev/sda" }

        it "does not include the device" do
          expect(subject.available_devices).to_not include(device)
        end
      end

      context "and the device contains a partition table" do
        context "and it does not contain partitions" do
          let(:device_name) { "/dev/sdc" }

          before do
            device.create_partition_table(Y2Storage::PartitionTables::Type::GPT)
          end

          it "includes the device" do
            expect(subject.available_devices).to include(device)
          end
        end

        context "and it contains partitions" do
          let(:device_name) { "/dev/sda" }

          it "does not include the device" do
            expect(subject.available_devices).to_not include(device)
          end
        end
      end

      context "when the device does not contain a partition table" do
        let(:device_name) { "/dev/sdc" }

        context "and the device is not component of another device" do
          it "includes the device" do
            expect(subject.available_devices).to include(device)
          end
        end

        context "and the device is component of another device" do
          before do
            md = Y2Storage::Md.create(current_graph, "/dev/md0")
            device.remove_descendants
            md.add_device(device)
          end

          it "does not include the device" do
            expect(subject.available_devices).to_not include(device)
          end
        end
      end
    end
  end

  describe "#selected_devices" do
    let(:scenario) { "complex-lvm-encrypt" }

    let(:cr_sda4) { current_graph.find_by_name("/dev/mapper/cr_sda4") }
    let(:sda3) { current_graph.find_by_name("/dev/sda3") }

    let(:device_name) { "/dev/sdb" }

    let(:filesystem) { device.filesystem }

    before do
      device.remove_descendants
      device.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)

      cr_sda4.remove_descendants
      device.filesystem.add_device(cr_sda4)
      device.filesystem.add_device(sda3)
    end

    it "includes the devices directly used by the Btrfs" do
      expect(subject.selected_devices).to include(sda3)
    end

    it "includes the devices used by the Btrfs through an encryption device" do
      expect(subject.selected_devices).to include(cr_sda4.blk_device)
    end

    it "does not include the encryption devices used by the Btrfs" do
      expect(subject.selected_devices).to_not include(cr_sda4)
    end
  end

  describe "#add_device" do
    context "if there is no filesystem yet" do
      let(:filesystem) { nil }

      let(:device_name) { "/dev/sdc" }

      it "creates a new Btrfs filesystem over the device" do
        expect(subject.filesystem).to be_nil
        expect(device.filesystem).to be_nil

        subject.add_device(device)

        expect(subject.filesystem).to_not be_nil
        expect(subject.filesystem.is?(:btrfs)).to eq(true)
        expect(subject.filesystem).to eq(device.filesystem)
      end
    end

    context "if there is already a filesystem" do
      let(:sdc) { current_graph.find_by_name("/dev/sdc") }

      let(:filesystem) { sdc.filesystem }

      let(:device_name) { "/dev/sdb6" }

      before do
        sdc.remove_descendants
        sdc.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
      end

      it "adds the device to the used devices of the Btrfs" do
        expect(filesystem.blk_devices).to contain_exactly(sdc)

        subject.add_device(device)

        expect(filesystem.blk_devices).to contain_exactly(sdc, device)
      end

      context "and the device was formatted" do
        it "removes the previous filesystem from the device" do
          expect(device.filesystem.type.is?(:xfs)).to eq(true)

          subject.add_device(device)

          expect(device.filesystem.type.is?(:btrfs)).to eq(true)
          expect(device.filesystem).to eq(subject.filesystem)
        end
      end

      context "and the device was encrypted" do
        before do
          device.remove_descendants
          device.create_encryption("cr_device")
        end

        it "does not remove the previous encryption from the device" do
          expect(device.encrypted?).to eq(true)

          subject.add_device(device)

          expect(device.encrypted?).to eq(true)
        end
      end
    end
  end

  describe "#remove_device" do
    let(:sdc) { current_graph.find_by_name("/dev/sdc") }

    let(:filesystem) { sdc.filesystem }

    let(:device_name) { "/dev/sdb6" }

    before do
      sdc.remove_descendants
      sdc.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)

      device.remove_descendants
      sdc.filesystem.add_device(device)
    end

    it "removes the device from the Btrfs" do
      expect(subject.filesystem.blk_devices).to include(device)

      subject.remove_device(device)

      expect(subject.filesystem.blk_devices).to_not include(device)
    end

    it "does not remove any other device from the Btrfs" do
      subject.remove_device(device)

      expect(subject.filesystem.blk_devices).to include(sdc)
    end
  end
end
