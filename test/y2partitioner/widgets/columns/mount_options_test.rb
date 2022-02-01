#!/usr/bin/env rspec

# Copyright (c) [2022] SUSE LLC
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
require_relative "./shared_examples"

require "y2partitioner/widgets/columns/mount_options"
require "y2storage/filesystems/legacy_nfs"

describe Y2Partitioner::Widgets::Columns::MountOptions do
  subject { described_class.new }

  include_examples "Y2Partitioner::Widgets::Column"

  let(:scenario) { "btrfs2-devicegraph.xml" }
  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { devicegraph.find_by_name(device_name) }

  before do
    devicegraph_stub(scenario)
  end

  describe "#value_for" do
    shared_examples "device mount options" do
      def device_with_mount_point
        return device if device.is?(:filesystem, :btrfs_subvolume)

        device.filesystem
      end

      context "and it is mounted" do
        before do
          dev = device_with_mount_point
          dev.remove_mount_point if dev.mount_point
          dev.create_mount_point("/test")
          dev.mount_point.mount_options = ["rw", "fsck"]
        end

        it "returns its mount options separated by comma" do
          expect(subject.value_for(device)).to eq("rw,fsck")
        end
      end

      context "and it is not mounted" do
        before do
          dev = device_with_mount_point
          dev.remove_mount_point if dev.mount_point
        end

        it "returns an empty string" do
          expect(subject.value_for(device)).to eq("")
        end
      end
    end

    context "when the given device is formatted" do
      let(:device_name) { "/dev/sda3" }

      include_examples "device mount options"
    end

    context "when the given device is a filesystem" do
      let(:device) { devicegraph.find_by_name("/dev/sdb1").filesystem }

      include_examples "device mount options"
    end

    context "when the given device is a Btrfs subvolume" do
      let(:filesystem) { devicegraph.find_by_name("/dev/sdb1").filesystem }
      let(:device) { filesystem.btrfs_subvolumes.find { |s| s.path == "sub1" } }

      include_examples "device mount options"
    end

    context "when the given device is not formatted" do
      let(:device_name) { "/dev/sda3" }

      before do
        device.delete_filesystem
      end

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when the given device is part of a multidevice filesystem" do
      let(:device_name) { "/dev/sdb1" }

      it "returns an empty string" do
        expect(subject.value_for(device)).to eq("")
      end
    end

    context "when the given device is a legacy NFS" do
      let(:device) { Y2Storage::Filesystems::LegacyNfs.new }

      before do
        device.server = "test"
        device.path = "/test"
        device.mountpoint = "/mnt/test"
        device.fstopt = "rw,fsck"
      end

      it "returns its mount options separated by comma" do
        expect(subject.value_for(device)).to eq("rw,fsck")
      end
    end
  end
end
