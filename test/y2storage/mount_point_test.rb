#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

describe Y2Storage::MountPoint do
  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "mixed_disks_btrfs" }

  let(:blk_device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, dev_name) }

  subject(:mount_point) { blk_device.blk_filesystem.mount_point }

  let(:dev_name) { "/dev/sda2" }

  describe "#mount_options=" do
    let(:mount_options) { ["rw", "minorversion=1"] }

    it "sets the given mount options" do
      mount_point.mount_options = mount_options
      expect(mount_point.mount_options).to eq(mount_options)
    end

    it "removes previous mount options" do
      mount_point.mount_options = ["ro"]
      expect(mount_point.mount_options).to include("ro")

      mount_point.mount_options = mount_options
      expect(mount_point.mount_options).to_not include("ro")
    end
  end

  describe "#mount_by" do
    context "for non-btrfs" do
      let(:dev_name) { "/dev/sdb5" } # XFS /home
      subject { blk_device.blk_filesystem.mount_point }

      before do
        subject.mount_by = Y2Storage::Filesystems::MountByType::ID
      end

      it "returns the correct mount_by" do
        expect(subject.mount_by.to_sym).to eq :id
      end
    end

    context "for btrfs" do
      let(:dev_name) { "/dev/sda2" } # Btrfs /, mount_by: label
      let(:btrfs) { blk_device.blk_filesystem }

      it "returns the correct mount_by mode" do
        expect(btrfs.mount_point.mount_by.to_sym).to eq :label
      end

      it "subvolumes inherit the mount_by mode from the parent btrfs" do
        # Don't use the first two subvolumes: They don't have a mount point.
        # One is the toplevel subvolume, one is the default subvolume.
        expect(btrfs.btrfs_subvolumes.last.mount_point.mount_by.to_sym).to eq :label
      end
    end
  end

  describe "#ensure_suitable_mount_by with ID as default mount_by" do
    let(:scenario) { "bug_1151075.xml" }
    let(:filesystem) { blk_device.filesystem }
    subject(:mount_point) { filesystem.create_mount_point("/") }

    before do
      conf = Y2Storage::StorageManager.instance.configuration
      conf.default_mount_by = Y2Storage::Filesystems::MountByType::ID
    end

    context "for a partition with udev path and without label" do
      let(:dev_name) { "/dev/nvme1n1p1" }

      it "leaves #mount_by untouched if it was previously set to PATH" do
        mount_point.mount_by = Y2Storage::Filesystems::MountByType::PATH
        mount_point.ensure_suitable_mount_by
        expect(mount_point.mount_by.is?(:path))
      end

      it "sets #mount_by to the default if it was previously set to LABEL" do
        mount_point.mount_by = Y2Storage::Filesystems::MountByType::LABEL
        mount_point.ensure_suitable_mount_by
        expect(mount_point.mount_by.is?(:id))
      end

      it "leaves #mount_by untouched if it was previously set to UUID" do
        mount_point.mount_by = Y2Storage::Filesystems::MountByType::UUID
        mount_point.ensure_suitable_mount_by
        expect(mount_point.mount_by.is?(:uuid))
      end
    end

    context "for a logical volume without label" do
      let(:dev_name) { "/dev/volgroup/lv1" }

      it "sets #mount_by to DEVICE if it was previously set to PATH" do
        mount_point.mount_by = Y2Storage::Filesystems::MountByType::PATH
        mount_point.ensure_suitable_mount_by
        expect(mount_point.mount_by.is?(:device))
      end

      it "sets #mount_by to DEVICE if it was previously set to LABEL" do
        mount_point.mount_by = Y2Storage::Filesystems::MountByType::LABEL
        mount_point.ensure_suitable_mount_by
        expect(mount_point.mount_by.is?(:device))
      end

      it "leaves #mount_by untouched if it was previously set to UUID" do
        mount_point.mount_by = Y2Storage::Filesystems::MountByType::UUID
        mount_point.ensure_suitable_mount_by
        expect(mount_point.mount_by.is?(:uuid))
      end
    end

    context "for a NFS share" do
      let(:blk_device) { nil }
      subject(:filesystem) { fake_devicegraph.nfs_mounts.first }

      it "sets #mount_by to DEVICE if it was previously set to PATH" do
        mount_point.mount_by = Y2Storage::Filesystems::MountByType::PATH
        mount_point.ensure_suitable_mount_by
        expect(mount_point.mount_by.is?(:device))
      end

      it "sets #mount_by to DEVICE if it was previously set to LABEL" do
        mount_point.mount_by = Y2Storage::Filesystems::MountByType::LABEL
        mount_point.ensure_suitable_mount_by
        expect(mount_point.mount_by.is?(:device))
      end

      it "sets #mount_by to DEVICE if it was previously set to LABEL" do
        mount_point.mount_by = Y2Storage::Filesystems::MountByType::UUID
        mount_point.ensure_suitable_mount_by
        expect(mount_point.mount_by.is?(:uuid))
      end
    end
  end

  describe "#suitable_mount_bys" do
    let(:scenario) { "encrypted_partition.xml" }
    let(:filesystem) { blk_device.filesystem }

    context "for a block device with all the udev links" do
      let(:dev_name) { "/dev/sda2" }

      subject(:mount_point) { filesystem.create_mount_point("/") }

      context "if the filesystem has a label" do
        before { filesystem.label = "something" }

        it "returns all the existing types" do
          expect(mount_point.suitable_mount_bys)
            .to contain_exactly(*Y2Storage::Filesystems::MountByType.all)
        end
      end

      context "if the filesystem has no label" do
        it "returns all the existing types except LABEL" do
          types = Y2Storage::Filesystems::MountByType.all.reject { |t| t.is?(:label) }
          expect(mount_point.suitable_mount_bys).to contain_exactly(*types)
        end
      end
    end

    context "for an encrypted device" do
      let(:dev_name) { "/dev/mapper/cr_sda1" }

      subject(:mount_point) { filesystem.create_mount_point("/") }

      context "if the filesystem has a label" do
        before { filesystem.label = "something" }

        it "returns all the existing types except the ones associated to udev links" do
          types = Y2Storage::Filesystems::MountByType.all.reject { |t| t.is?(:id, :path) }
          expect(mount_point.suitable_mount_bys).to contain_exactly(*types)
        end
      end

      context "if the filesystem has no label" do
        it "returns only DEVICE and UUID" do
          expect(mount_point.suitable_mount_bys).to contain_exactly(
            Y2Storage::Filesystems::MountByType::DEVICE, Y2Storage::Filesystems::MountByType::UUID
          )
        end
      end
    end
  end

  describe "#passno" do
    let(:scenario) { "empty_hard_disk_50GiB" }

    let(:dev_name) { "/dev/sda" }
    let(:filesystem) { blk_device.create_filesystem(fs_type) }
    subject(:mount_point) { filesystem.create_mount_point(path) }

    context "for an ext4 filesystem" do
      let(:fs_type) { Y2Storage::Filesystems::Type::EXT4 }

      context "mounted at /" do
        let(:path) { "/" }

        it "is set to 1" do
          expect(mount_point.passno).to eq 1
        end

        context "and later reassigned to another path" do
          it "is set to 2" do
            mount_point.path = "/var"
            expect(mount_point.passno).to eq 2
          end
        end
      end

      context "mounted at a non-root location" do
        let(:path) { "/home" }

        it "is set to 2" do
          expect(mount_point.passno).to eq 2
        end
      end
    end

    context "for an xfs filesystem" do
      let(:fs_type) { Y2Storage::Filesystems::Type::XFS }

      context "mounted at /" do
        let(:path) { "/" }

        it "is set to 0" do
          expect(mount_point.passno).to eq 0
        end
      end

      context "mounted at a non-root location" do
        let(:path) { "/home" }

        it "is set to 0" do
          expect(mount_point.passno).to eq 0
        end
      end
    end

    context "for an BTRFS filesystem" do
      let(:fs_type) { Y2Storage::Filesystems::Type::BTRFS }
      let(:specs) do
        [Y2Storage::SubvolSpecification.new("foo"), Y2Storage::SubvolSpecification.new("bar")]
      end

      RSpec.shared_examples "passno 0 with subvolumes" do
        it "is set to 0 for the filesystem and all its subvolumes" do
          expect(mount_point.passno).to eq 0

          filesystem.add_btrfs_subvolumes(specs)
          mount_points = filesystem.btrfs_subvolumes.map(&:mount_point).compact
          expect(mount_points.size).to eq specs.size
          expect(mount_points.map(&:passno)).to all(eq(0))
        end
      end

      context "mounted at /" do
        let(:path) { "/" }
        include_examples "passno 0 with subvolumes"
      end

      context "mounted at a non-root location" do
        let(:path) { "/home" }
        include_examples "passno 0 with subvolumes"
      end
    end

    context "for an NFS filesystem" do
      let(:filesystem) { Y2Storage::Filesystems::Nfs.create(fake_devicegraph, "server", path) }

      context "mounted at /" do
        let(:path) { "/" }

        it "is set to 0" do
          expect(mount_point.passno).to eq 0
        end
      end

      context "mounted at a non-root location" do
        let(:path) { "/home" }

        it "is set to 0" do
          expect(mount_point.passno).to eq 0
        end
      end
    end
  end
end
