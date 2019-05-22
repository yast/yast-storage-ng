#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018-2019] SUSE LLC
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
require "y2partitioner/actions/controllers/blk_device"

describe Y2Partitioner::Actions::Controllers::BlkDevice do
  before do
    devicegraph_stub(scenario)
  end

  subject(:controller) { described_class.new(device) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:scenario) { "mixed_disks.yml" }

  def create_partition(disk_name)
    disk = current_graph.find_by_name(disk_name)
    slot = disk.partition_table.unused_partition_slots.first
    part = disk.partition_table.create_partition(
      slot.name,
      slot.region,
      Y2Storage::PartitionType::PRIMARY
    )
    part.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
  end

  describe "#initialize" do
    context "when the given device is a block device" do
      let(:device_name) { "/dev/sda" }

      it "does not raise an exception" do
        expect { described_class.new(device) }.to_not raise_error
      end
    end

    context "when the given device is not a blk device" do
      let(:scenario) { "dos_lvm" }
      let(:device_name) { "/dev/vg0" }

      it "raises an exception" do
        expect { described_class.new(device) }.to raise_error(TypeError)
      end
    end
  end

  describe "#committed_current_filesystem?" do
    context "when the device is not currently formatted" do
      let(:device_name) { "/dev/sdb7" }

      it "returns false" do
        expect(controller.committed_current_filesystem?).to eq(false)
      end
    end

    context "when the device is currently formatted" do
      context "but it does not exist on the system yet" do
        before do
          create_partition("/dev/sdc")
        end

        let(:device_name) { "/dev/sdc1" }

        it "returns false" do
          expect(controller.committed_current_filesystem?).to eq(false)
        end
      end

      context "but it is not formatted on system" do
        let(:device_name) { "/dev/sdb7" }

        before do
          device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
        end

        it "returns false" do
          expect(controller.committed_current_filesystem?).to eq(false)
        end
      end

      context "and it is formatted on system" do
        let(:device_name) { "/dev/sda2" }

        context "but the current filesystem does not match to the filesystem on system" do
          before do
            device.delete_filesystem
            device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
          end

          it "returns false" do
            expect(controller.committed_current_filesystem?).to eq(false)
          end
        end

        context "and the current filesystem matches to the filesystem on system" do
          it "returns true" do
            expect(controller.committed_current_filesystem?).to eq(true)
          end
        end
      end
    end
  end

  describe "#mounted_committed_filesystem?" do
    context "when the device does not exist on the system yet" do
      before do
        create_partition("/dev/sdc")
      end

      let(:device_name) { "/dev/sdc1" }

      it "returns false" do
        expect(controller.mounted_committed_filesystem?).to eq(false)
      end
    end

    context "when the device is not formatted on the system" do
      let(:device_name) { "/dev/sdb7" }

      it "returns false" do
        expect(controller.mounted_committed_filesystem?).to eq(false)
      end
    end

    context "when the device is formatted on the system" do
      context "and the filesystem on the system has not mount point" do
        let(:device_name) { "/dev/sdb7" }

        it "returns false" do
          expect(controller.mounted_committed_filesystem?).to eq(false)
        end
      end

      context "and the filesystem on the system has mount point" do
        let(:device_name) { "/dev/sdb2" }

        before do
          system_devicegraph = Y2Storage::StorageManager.instance.system
          part = system_devicegraph.find_by_name(device_name)
          part.mount_point.active = active
        end

        context "and the mount point is not active" do
          let(:active) { false }

          it "returns false" do
            expect(controller.mounted_committed_filesystem?).to eq(false)
          end
        end

        context "and the mount point is active" do
          let(:active) { true }

          it "returns true" do
            expect(controller.mounted_committed_filesystem?).to eq(true)
          end
        end
      end
    end
  end

  describe "#multidevice_filesystem?" do
    let(:scenario) { "btrfs2-devicegraph.xml" }

    context "when the device is not formatted" do
      let(:device_name) { "/dev/sda2" }

      before do
        device.delete_filesystem
      end

      it "returns false" do
        expect(controller.multidevice_filesystem?).to eq(false)
      end
    end

    context "when the device is formatted" do
      context "and it used by a single-device filesystem" do
        let(:device_name) { "/dev/sda2" }

        it "returns false" do
          expect(controller.multidevice_filesystem?).to eq(false)
        end
      end

      context "and it used by a multi-device filesystem" do
        let(:device_name) { "/dev/sdb1" }

        it "returns true" do
          expect(controller.multidevice_filesystem?).to eq(true)
        end
      end
    end
  end

  describe "#committed_device?" do
    context "when the device does not exist on the system yet" do
      before do
        create_partition("/dev/sdc")
      end

      let(:device_name) { "/dev/sdc1" }

      it "returns false" do
        expect(controller.committed_device?).to eq(false)
      end
    end

    context "when the device exists on the system" do
      let(:device_name) { "/dev/sda1" }

      it "returns true" do
        expect(controller.committed_device?).to eq(true)
      end
    end
  end

  describe "#committed_device" do
    context "when the device does not exist on the system yet" do
      before do
        create_partition("/dev/sdc")
      end

      let(:device_name) { "/dev/sdc1" }

      it "returns nil" do
        expect(controller.committed_device).to be_nil
      end
    end

    context "when the device exists on the system" do
      let(:device_name) { "/dev/sda1" }

      it "returns the device on the system" do
        expect(controller.committed_device).to be_a(Y2Storage::BlkDevice)
        expect(controller.committed_device.name).to eq("/dev/sda1")

        system = Y2Storage::StorageManager.instance.system

        expect(controller.committed_device.exists_in_devicegraph?(system)).to eq(true)
      end
    end
  end

  describe "#committed_filesystem?" do
    context "when the device does not exist on the system yet" do
      before do
        create_partition("/dev/sdc")
      end

      let(:device_name) { "/dev/sdc1" }

      it "returns false" do
        expect(controller.committed_filesystem?).to eq(false)
      end
    end

    context "when the device exists on the system" do
      context "but it is not formatted" do
        let(:device_name) { "/dev/sdb7" }

        it "returns false" do
          expect(controller.committed_filesystem?).to eq(false)
        end
      end

      context "and it is formatted" do
        let(:device_name) { "/dev/sdb2" }

        it "returns true" do
          expect(controller.committed_filesystem?).to eq(true)
        end
      end
    end
  end

  describe "#committed_filesystem" do
    context "when the device does not exist on the system yet" do
      before do
        create_partition("/dev/sdc")
      end

      let(:device_name) { "/dev/sdc1" }

      it "returns nil" do
        expect(controller.committed_filesystem).to be_nil
      end
    end

    context "when the device exists on the system" do
      context "but it is not formatted" do
        let(:device_name) { "/dev/sdb7" }

        it "returns nil" do
          expect(controller.committed_filesystem).to be_nil
        end
      end

      context "and it is formatted" do
        let(:device_name) { "/dev/sdb2" }

        it "returns the filesystem on the system" do
          expect(controller.committed_filesystem).to be_a(Y2Storage::Filesystems::Base)
          expect(controller.committed_filesystem.type.is?("btrfs"))

          system = Y2Storage::StorageManager.instance.system

          expect(controller.committed_filesystem.exists_in_devicegraph?(system)).to eq(true)
        end
      end
    end
  end

  shared_examples "checks mounted committed filesystem" do
    context "when the device does not exist on the system yet" do
      before do
        create_partition("/dev/sdc")
      end

      let(:device_name) { "/dev/sdc1" }

      it "returns false" do
        expect(controller.send(described_method)).to eq(false)
      end
    end

    context "when the device is not formatted on the system" do
      let(:device_name) { "/dev/sdb7" }

      it "returns false" do
        expect(controller.send(described_method)).to eq(false)
      end
    end

    context "when the device is formatted on the system" do
      context "and the filesystem on the system has not mount point" do
        let(:device_name) { "/dev/sdb7" }

        it "returns false" do
          expect(controller.send(described_method)).to eq(false)
        end
      end

      context "and the filesystem on the system has mount point" do
        let(:device_name) { "/dev/sdb2" }

        before do
          system_devicegraph = Y2Storage::StorageManager.instance.system
          part = system_devicegraph.find_by_name(device_name)
          part.mount_point.active = active
        end

        context "and the mount point is not active" do
          let(:active) { false }

          it "returns false" do
            expect(controller.send(described_method)).to eq(false)
          end
        end
      end
    end
  end

  describe "#unmount_for_shrinking?" do
    let(:described_method) { :unmount_for_shrinking? }

    include_examples "checks mounted committed filesystem"

    context "when the committed filesystem does not support to shrink being mounted" do
      let(:device_name) { "/dev/sdb2" }

      before do
        allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem)
          .to receive(:supports_mounted_shrink?).and_return(false)
      end

      it "returns true" do
        expect(controller.unmount_for_shrinking?).to eq(true)
      end
    end

    context "when the committed filesystem supports to shrink being mounted" do
      let(:device_name) { "/dev/sdb2" }

      before do
        allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem)
          .to receive(:supports_mounted_shrink?).and_return(true)
      end

      it "returns false" do
        expect(controller.unmount_for_shrinking?).to eq(false)
      end
    end
  end

  describe "#unmount_for_growing?" do
    let(:described_method) { :unmount_for_growing? }

    include_examples "checks mounted committed filesystem"

    context "when the committed filesystem does not support to grow being mounted" do
      let(:device_name) { "/dev/sdb2" }

      before do
        allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem)
          .to receive(:supports_mounted_grow?).and_return(false)
      end

      it "returns true" do
        expect(controller.unmount_for_growing?).to eq(true)
      end
    end

    context "when the committed filesystem supports to grow being mounted" do
      let(:device_name) { "/dev/sdb2" }

      before do
        allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem)
          .to receive(:supports_mounted_grow?).and_return(true)
      end

      it "returns false" do
        expect(controller.unmount_for_growing?).to eq(false)
      end
    end
  end
end
