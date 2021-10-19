#!/usr/bin/env rspec
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

require_relative "../spec_helper"
require "y2storage"

describe "default mount_by when creating a mount point" do
  before do
    fake_scenario(scenario)
    conf = Y2Storage::StorageManager.instance.configuration
    conf.default_mount_by = mount_by_type
  end

  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, dev_name) }
  subject(:filesystem) { blk_device.filesystem }

  describe "Mountable#create_mount_point" do
    let(:scenario) { "encrypted_probed_partition.xml" }
    let(:dev_name) { "/dev/mapper/cr_sda1" }

    context "with DEVICE being the default mount_by" do
      let(:mount_by_type) { Y2Storage::Filesystems::MountByType::DEVICE }

      context "mounting an encrypted partition" do
        it "mounts by device" do
          mp = filesystem.create_mount_point("/foo")
          expect(mp.mount_by.is?(:device)).to eq true
        end

        it "uses device name in crypttab" do
          mp = filesystem.create_mount_point("/foo")
          expect(mp.filesystem.blk_devices.first.mount_by.is?(:device)).to eq true
        end
      end
    end

    context "with UUID being the default mount_by" do
      let(:mount_by_type) { Y2Storage::Filesystems::MountByType::UUID }

      context "mounting an encrypted partition" do
        it "mounts by device name" do
          mp = filesystem.create_mount_point("/foo")
          expect(mp.mount_by.is?(:device)).to eq true
        end

        it "uses uuid in crypttab" do
          mp = filesystem.create_mount_point("/foo")
          expect(mp.filesystem.blk_devices.first.mount_by.is?(:uuid)).to eq true
        end
      end
    end

    context "with LABEL being the default mount_by" do
      let(:mount_by_type) { Y2Storage::Filesystems::MountByType::LABEL }

      context "mounting an encrypted partition" do
        it "mounts by device name" do
          mp = filesystem.create_mount_point("/foo")
          expect(mp.mount_by.is?(:device)).to eq true
        end

        it "uses uuid in crypttab" do
          mp = filesystem.create_mount_point("/foo")
          expect(mp.filesystem.blk_devices.first.mount_by.is?(:uuid)).to eq true
        end
      end
    end

    context "with PATH being the default mount_by" do
      let(:mount_by_type) { Y2Storage::Filesystems::MountByType::PATH }

      # This is a modified version of the scenario of the bug to include more cases.
      # The original report was about the installer using the device name to mount
      # those devices without an udev path (mounting by path is the default in s390).
      let(:scenario) { "bug_1151075.xml" }

      context "mounting a partition with udev path" do
        let(:dev_name) { "/dev/nvme1n1p1" }

        it "mounts by path" do
          mp = filesystem.create_mount_point("/")
          expect(mp.mount_by.is?(:path)).to eq true
        end
      end

      # Regression test for bug#1151075
      context "mounting a partition without udev path" do
        let(:dev_name) { "/dev/nvme5n1p1" }

        it "mounts by UUID" do
          mp = filesystem.create_mount_point("/")
          expect(mp.mount_by.is?(:uuid)).to eq true
        end
      end

      context "mounting a logical volume" do
        let(:dev_name) { "/dev/volgroup/lv1" }

        it "mounts by device name" do
          mp = filesystem.create_mount_point("/")
          expect(mp.mount_by.is?(:device)).to eq true
        end
      end

      context "mounting an encrypted device" do
        let(:dev_name) { "/dev/nvme2n1p1" }

        it "mounts by device name" do
          mp = filesystem.create_mount_point("/")
          expect(mp.mount_by.is?(:device)).to eq true
        end
      end

      context "mounting an NFS share" do
        let(:blk_device) { nil }
        subject(:filesystem) { fake_devicegraph.nfs_mounts.first }

        it "mounts by device name" do
          mp = filesystem.create_mount_point("/")
          expect(mp.mount_by.is?(:device)).to eq true
        end
      end
    end
  end
end
