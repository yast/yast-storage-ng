#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require_relative "../test_helper"
require "y2partitioner/sequences/filesystem_controller"

describe Y2Partitioner::Sequences::FilesystemController do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  subject { described_class.new(device) }

  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }

  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:dev_name) { "/dev/sda2" }

  describe "#blk_device" do
    it "returns a Y2Storage::BlkDevice" do
      expect(subject.blk_device).to be_a(Y2Storage::BlkDevice)
    end

    it "returns the currently editing block device" do
      expect(subject.blk_device.name).to eq(dev_name)
    end
  end

  describe "#filesystem" do
    it "returns the filesystem of the currently editing device" do
      expect(subject.filesystem).to eq(device.filesystem)
    end
  end

  describe "#filesystem_type" do
    context "when the currently editing device has a filesystem" do
      it "returns the filesystem type" do
        expect(subject.filesystem_type).to eq(device.filesystem.type)
      end
    end

    context "when the currently editing device has not a filesystem" do
      before do
        allow(device).to receive(:filesystem).and_return(nil)
        allow(subject).to receive(:blk_device).and_return(device)
      end

      it "returns nil" do
        expect(subject.filesystem_type).to be_nil
      end
    end
  end

  describe "#to_be_formatted?" do
    context "when the currently editing device has not a filesystem" do
      before do
        allow(device).to receive(:filesystem).and_return(nil)
        allow(subject).to receive(:blk_device).and_return(device)
      end

      it "returns false" do
        expect(subject.to_be_formatted?).to eq(false)
      end
    end

    context "when the currently editing device has a filesystem" do
      context "and the filesystem existed previously" do
        it "returns false" do
          expect(subject.to_be_formatted?).to eq(false)
        end
      end

      context "and the filesystem did not exist previously" do
        it "returns true" do
          subject
          device.remove_descendants
          device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)

          expect(subject.to_be_formatted?).to eq(true)
        end
      end
    end
  end

  describe "#to_be_encrypted?" do
    context "when the currently editing device has a filesystem that existed previously" do
      it "returns false" do
        expect(subject.to_be_encrypted?).to eq(false)
      end
    end

    context "when the currently editing device has not a filesystem that existed previously" do
      before do
        allow(subject).to receive(:encrypt).and_return(encrypt)
        allow(device).to receive(:encrypted?).and_return(encrypted)
        allow(device).to receive(:filesystem).and_return(filesystem)
        allow(subject).to receive(:blk_device).and_return(device)
      end

      let(:encrypt) { false }
      let(:encrypted) { false }
      let(:filesystem) { nil }

      context "and the device has not been marked to encrypt" do
        let(:encrypt) { false }

        it "returns false" do
          expect(subject.to_be_encrypted?).to eq(false)
        end
      end

      context "and the device has been marked to encrypt" do
        let(:encrypt) { true }

        context "and the device is currently encrypted" do
          let(:encrypted) { true }

          it "returns false" do
            expect(subject.to_be_encrypted?).to eq(false)
          end
        end

        context "and the device is not currently encrypted" do
          let(:encrypted) { false }

          it "returns true" do
            expect(subject.to_be_encrypted?).to eq(true)
          end
        end
      end
    end
  end

  describe "#mount_point" do
    context "when the currently editing device has a filesystem" do
      it "returns the filesystem mount point" do
        expect(subject.mount_point).to eq(device.filesystem.mount_point)
      end
    end

    context "when the currently editing device has not a filesystem" do
      before do
        allow(device).to receive(:filesystem).and_return(nil)
        allow(subject).to receive(:blk_device).and_return(device)
      end

      it "returns nil" do
        expect(subject.mount_point).to be_nil
      end
    end
  end

  describe "#partition_id" do
    context "when the currently editing device is a partition" do
      it "returns its id" do
        expect(subject.partition_id).to eq(device.id)
      end
    end

    context "when the currently editing device is not a partition" do
      let(:dev_name) { "/dev/sdc" }

      it "returns nil" do
        expect(subject.partition_id).to be_nil
      end
    end
  end

  describe "#apply_role" do
    before do
      subject.role = role
    end

    let(:role) { nil }

    it "sets encrypt to false" do
      subject.encrypt = true
      subject.apply_role

      expect(subject.encrypt).to eq(false)
    end

    context "when selected role is :swap" do
      let(:role) { :swap }

      it "sets partition_id to SWAP" do
        subject.apply_role
        expect(subject.partition_id).to eq(Y2Storage::PartitionId::SWAP)
      end

      it "creates a swap filesystem" do
        subject.apply_role
        expect(subject.filesystem.type).to eq(Y2Storage::Filesystems::Type::SWAP)
      end

      it "sets mount point to 'swap'" do
        subject.apply_role
        expect(subject.filesystem.mount_point).to eq("swap")
      end

      it "sets mount by to 'device'" do
        subject.apply_role
        expect(subject.filesystem.mount_by).to eq(Y2Storage::Filesystems::MountByType::DEVICE)
      end
    end

    context "when selected role is :efi_boot" do
      let(:role) { :efi_boot }

      it "sets partition_id to ESP" do
        subject.apply_role
        expect(subject.partition_id).to eq(Y2Storage::PartitionId::ESP)
      end

      it "creates a vfat filesystem" do
        subject.apply_role
        expect(subject.filesystem.type).to eq(Y2Storage::Filesystems::Type::VFAT)
      end

      it "sets mount point to '/boot/efi'" do
        subject.apply_role
        expect(subject.filesystem.mount_point).to eq("/boot/efi")
      end
    end

    context "when selected role is :raw" do
      let(:role) { :raw }

      it "sets partition_id to LVM" do
        subject.apply_role
        expect(subject.partition_id).to eq(Y2Storage::PartitionId::LVM)
      end

      it "does not create a filesystem" do
        subject.apply_role
        expect(subject.filesystem).to be_nil
      end
    end

    context "when selected role is :system" do
      let(:role) { :system }

      it "sets partition_id to LINUX" do
        subject.apply_role
        expect(subject.partition_id).to eq(Y2Storage::PartitionId::LINUX)
      end

      it "creates a BTRFS filesystem" do
        subject.apply_role
        expect(subject.filesystem.type).to eq(Y2Storage::Filesystems::Type::BTRFS)
      end

      it "does not set a mount point" do
        subject.apply_role
        expect(subject.filesystem.mount_point).to be_nil
      end
    end

    context "when selected role is :data" do
      let(:role) { :data }

      it "sets partition_id to LINUX" do
        subject.apply_role
        expect(subject.partition_id).to eq(Y2Storage::PartitionId::LINUX)
      end

      it "creates a XFS filesystem" do
        subject.apply_role
        expect(subject.filesystem.type).to eq(Y2Storage::Filesystems::Type::XFS)
      end

      it "does not set a mount point" do
        subject.apply_role
        expect(subject.filesystem.mount_point).to be_nil
      end
    end
  end

  describe "#new_filesystem" do
    let(:type) { Y2Storage::Filesystems::Type::EXT4 }

    it "deletes previous filesystem in the currently editing device" do
      fs_sid = device.filesystem.sid
      subject.new_filesystem(type)

      expect(Y2Partitioner::DeviceGraphs.instance.current.find_device(fs_sid)).to be_nil
    end

    it "creates a new filesystem with the indicated type in the currently editing device" do
      subject.new_filesystem(type)
      expect(subject.blk_device.filesystem.type).to eq(type)
    end

    context "when the type for the new partition is swap" do
      let(:type) { Y2Storage::Filesystems::Type::SWAP }

      it "sets mount point to swap" do
        subject.new_filesystem(type)
        expect(subject.blk_device.filesystem.mount_point).to eq("swap")
      end
    end

    context "when the currently editing device has already a filesystem" do
      before do
        device.filesystem.mount_point = mount_point
        device.filesystem.mount_by = mount_by
        device.filesystem.label = label
      end

      let(:mount_point) { "/foo" }
      let(:mount_by) { Y2Storage::Filesystems::MountByType::DEVICE }
      let(:label) { "foo" }

      it "preserves the mount point" do
        subject.new_filesystem(type)
        expect(subject.blk_device.filesystem.mount_point).to eq(mount_point)
      end

      it "preserves the mount by property" do
        subject.new_filesystem(type)
        expect(subject.blk_device.filesystem.mount_by).to eq(mount_by)
      end

      it "sets the proper partition id" do
        subject.new_filesystem(type)
        expect(subject.partition_id).to eq(type.default_partition_id)
      end

      context "when the previous filesystem exists in the disk" do
        it "does not preserve the label" do
          subject.new_filesystem(type)
          expect(subject.blk_device.filesystem.label).to be_empty
        end
      end

      context "when the previous filesystem does not exist in the disk" do
        before do
          subject
          device.remove_descendants
          device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
          device.filesystem.label = label
        end

        it "preserves the label" do
          subject.new_filesystem(type)
          expect(subject.blk_device.filesystem.label).to eq(label)
        end
      end
    end
  end

  describe "#dont_format" do
    context "when the currently editing device has not a filesystem" do
      before do
        device.remove_descendants
      end

      it "does nothing" do
        devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
        subject.dont_format

        expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
      end
    end

    context "when the filesystem has not changed" do
      it "does nothing" do
        devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
        subject.dont_format

        expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
      end
    end

    context "when the filesystem has changed" do
      before do
        subject.new_filesystem(Y2Storage::Filesystems::Type::EXT4)
      end

      context "and there was a previous filesystem" do
        it "restores previous filesystem" do
          subject.dont_format
          expect(subject.filesystem.type).to eq(Y2Storage::Filesystems::Type::BTRFS)
        end
      end

      context "and there was not a previous filesystem" do
        before do
          device.remove_descendants
        end

        it "removes current filesystem" do
          subject.dont_format
          expect(subject.filesystem).to be_nil
        end
      end
    end
  end

  describe "#partition_id=" do
    context "when tries to set nil" do
      it "does nothing" do
        devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
        subject.partition_id = nil

        expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
      end
    end

    context "when the currently editing device is not a partition" do
      let(:dev_name) { "/dev/sdc" }

      it "does nothing" do
        devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
        subject.partition_id = Y2Storage::PartitionId::SWAP

        expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
      end
    end

    context "when the currently editing device is a partition" do
      let(:dev_name) { "/dev/sda2" }

      let(:partition_id) { Y2Storage::PartitionId::SWAP }

      it "sets the partition_id" do
        subject.partition_id = partition_id
        expect(subject.partition_id).to eq(partition_id)
      end

      it "updates the device id" do
        subject.partition_id = partition_id
        expect(subject.blk_device.id).to eq(partition_id)
      end
    end
  end

  describe "#finish" do
    before do
      allow(subject).to receive(:can_change_encrypt?).and_return(can_change_encrypt)
    end

    context "when it is not possible to change the encrypt" do
      let(:can_change_encrypt) { false }

      it "does nothing" do
        devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
        subject.finish

        expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
      end
    end

    context "when it is possible to change the encrypt" do
      let(:can_change_encrypt) { true }

      before do
        allow(subject).to receive(:encrypt).and_return(encrypt)
        allow(subject).to receive(:encrypt_password).and_return(password)
      end

      let(:encrypt) { false }
      let(:password) { "12345678" }

      context "and the device was already encrypted" do
        before do
          device.remove_descendants
          encryption = device.create_encryption("foo")
          encryption.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
        end

        context "and it is marked to be encrypted" do
          let(:encrypt) { true }

          it "does nothing" do
            devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
            subject.finish

            expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
          end
        end

        context "and it is not marked to be encrypted" do
          let(:encrypt) { false }

          it "removes the encryption" do
            expect(subject.blk_device.encryption).to_not be_nil
            subject.finish
            expect(subject.blk_device.encryption).to be_nil
          end
        end
      end

      context "and the device is not encrypted" do
        context "and it is marked to be encrypted" do
          let(:encrypt) { true }

          it "encrypts the device" do
            subject.finish
            expect(subject.blk_device.encryption).to_not be_nil
            expect(subject.blk_device.encryption.password).to eq(password)
          end
        end

        context "and it is not marked to be encrypted" do
          let(:encrypt) { false }

          it "does nothing" do
            devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
            subject.finish

            expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
          end
        end
      end
    end
  end
end
