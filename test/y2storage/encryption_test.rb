#!/usr/bin/env rspec

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

require_relative "spec_helper"
require "y2storage/encryption"

describe Y2Storage::Encryption do
  before do
    fake_scenario(scenario)
  end

  let(:blk_device) { devicegraph.find_by_name(device_name) }

  let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

  describe "#auto_dm_table_name" do
    subject { blk_device.create_encryption("cr_test") }

    let(:scenario) { "mixed_disks" }

    let(:device_name) { "/dev/sda2" }

    before do
      allow(subject).to receive(:blk_device).and_return(blk_device)

      allow(subject).to receive(:mount_point).and_return(mount_point)

      allow(blk_device).to receive(:dm_table_name).and_return(dm_table_name)

      allow(blk_device).to receive(:udev_ids).and_return(udev_ids)
    end

    let(:mount_point) { nil }

    let(:dm_table_name) { "" }

    let(:udev_ids) { [] }

    shared_examples "repeated dm name" do |dm_name|
      context "and an encryption device with the same name already exists" do
        before do
          sda1 = devicegraph.find_by_name("/dev/sda1")

          sda1.create_encryption(dm_name)
        end

        it "adds a number-based suffix" do
          expect(subject.auto_dm_table_name).to eq(dm_name + "_2")
        end

        context "and an encryption name with the suffix also exists" do
          before do
            sdb1 = devicegraph.find_by_name("/dev/sdb1")

            sdb1.create_encryption(dm_name + "_2")
          end

          it "increases the number in the suffix as much as needed" do
            expect(subject.auto_dm_table_name).to eq(dm_name + "_3")
          end
        end
      end
    end

    context "when the underlying device has a device mapper name (e.g., an LVM LV)" do
      let(:dm_table_name) { "system-root" }

      it "generates an encryption name based on the device mapper name" do
        expect(subject.auto_dm_table_name).to eq("cr_system-root")
      end

      include_examples "repeated dm name", "cr_system-root"
    end

    context "when the underlying device has not a device mapper name" do
      let(:dm_table_name) { "" }

      context "and the encryption device is mounted" do
        let(:mount_point) do
          Y2Storage::MountPoint.new(Storage::MountPoint.create(devicegraph.to_storage_value, path))
        end

        context "and it is mounted as root" do
          let(:path) { "/" }

          it "generates an encryption name like 'cr_root'" do
            expect(subject.auto_dm_table_name).to eq("cr_root")
          end

          include_examples "repeated dm name", "cr_root"
        end

        context "and it is not mounted as root" do
          let(:path) { "/home/foo" }

          it "generates an encryption name based on the mount point" do
            expect(subject.auto_dm_table_name).to eq("cr_home_foo")
          end

          include_examples "repeated dm name", "cr_home_foo"
        end
      end

      context "and the encryption device is not mounted" do
        let(:mount_point) { nil }

        context "and some udev ids are recognized for the underlying device" do
          let(:udev_ids) { ["disk-1122-part2"] }

          it "generates an encryption name based on the udev id" do
            expect(subject.auto_dm_table_name).to eq("cr_disk-1122-part2")
          end

          include_examples "repeated dm name", "cr_disk-1122-part2"
        end

        context "and no udev ids are recognized for the underlying device" do
          let(:udev_ids) { [] }

          it "generates an encryption name based on the underlying device name" do
            expect(subject.auto_dm_table_name).to eq("cr_sda2")
          end

          include_examples "repeated dm name", "cr_sda2"
        end
      end
    end
  end

  describe ".match_crypttab_spec?" do
    subject { devicegraph.find_by_name(dev_name) }

    let(:scenario) { "encrypted_partition.xml" }

    let(:dev_name) { "/dev/mapper/cr_sda1" }

    it "returns true for the kernel name of the underlying device" do
      expect(subject.match_crypttab_spec?("/dev/sda1")).to eq(true)
    end

    it "returns true for any udev name of the underlying device" do
      subject.blk_device.udev_full_all.each do |name|
        expect(subject.match_crypttab_spec?(name)).to eq(true)
      end
    end

    it "returns false for the kernel name of the encryption device" do
      expect(subject.match_crypttab_spec?("/dev/mapper/cr_sda1")).to eq(false)
    end

    it "returns false for any udev name of the encryption device" do
      subject.udev_full_all.each do |name|
        expect(subject.match_crypttab_spec?(name)).to eq(false)
      end
    end

    it "returns false for other kernel name" do
      expect(subject.match_crypttab_spec?("/dev/sda2")).to eq(false)
    end

    it "returns false for other udev name" do
      expect(subject.match_crypttab_spec?("/dev/disks/by-uuid/111-2222-3333")).to eq(false)
    end
  end

  describe "setting the crypttab options" do
    let(:scenario) { "encrypted_partition.xml" }
    let(:disk) { devicegraph.find_by_name("/dev/sda") }
    let(:partition) { devicegraph.find_by_name(partition_name) }

    before { allow(disk.transport).to receive(:network?).and_return network }

    RSpec.shared_examples "netdev for network device" do
      context "within a network disk" do
        let(:network) { true }

        it "makes sure #crypt_options include _netdev" do
          expect(encryption.crypt_options).to include("_netdev")
        end
      end

      context "within a local disk" do
        let(:network) { false }

        it "makes no changes to #crypt_options" do
          expect(encryption.crypt_options).to be_empty
        end
      end
    end

    context "when mounting an encryption device that already existed" do
      let(:partition_name) { "/dev/sda1" }
      subject(:encryption) { partition.encryption }

      before do
        fs = encryption.filesystem
        fs.create_mount_point("/mnt")
        fs.mount_point.set_default_mount_options
      end

      include_examples "netdev for network device"
    end

    context "when encrypting and mounting a device" do
      let(:partition_name) { "/dev/sda2" }

      subject(:encryption) { partition.encryption }

      def create_btrfs(blk_dev)
        fs = blk_dev.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
        fs.create_mount_point("/")
        # To have full effect, this must be done after creating the mount point
        fs.add_btrfs_subvolumes(Y2Storage::SubvolSpecification.fallback_list)
        fs.mount_point.set_default_mount_options
        fs
      end

      before do
        partition.remove_descendants
        create_btrfs(partition.encrypt)
      end

      include_examples "netdev for network device"

      context "if the mount point is created before the encryption (e.g. Partitioner)" do
        before do
          partition.remove_descendants
          create_btrfs(partition)
          partition.encrypt
        end

        include_examples "netdev for network device"
      end
    end
  end
end
