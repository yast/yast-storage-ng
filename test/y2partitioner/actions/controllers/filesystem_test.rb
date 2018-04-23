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

require_relative "../../test_helper"
require "y2partitioner/actions/controllers/filesystem"

describe Y2Partitioner::Actions::Controllers::Filesystem do
  before do
    devicegraph_stub(scenario)
    allow(Y2Storage::VolumeSpecification).to receive(:for).and_call_original
    allow(Y2Storage::VolumeSpecification).to receive(:for).with("/")
      .and_return(volume_spec)
  end

  let(:scenario) { "mixed_disks_btrfs" }

  subject(:controller) { described_class.new(device, "The title") }

  let(:device) { Y2Storage::BlkDevice.find_by_name(devicegraph, dev_name) }

  let(:devicegraph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:dev_name) { "/dev/sda2" }

  let(:volume_spec) do
    instance_double(Y2Storage::VolumeSpecification,
      btrfs_default_subvolume: default_subvolume,
      subvolumes:              subvolumes,
      btrfs_read_only?:        false)
  end

  let(:default_subvolume) { "" }

  let(:subvolumes) { Y2Storage::SubvolSpecification.fallback_list }

  describe "#blk_device" do
    it "returns a Y2Storage::BlkDevice" do
      expect(subject.blk_device).to be_a(Y2Storage::BlkDevice)
    end

    it "returns the currently editing block device" do
      expect(subject.blk_device.name).to eq(dev_name)
    end
  end

  describe "wizard_title" do
    it "returns the string passed to the constructor" do
      expect(controller.wizard_title).to eq "The title"
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
      context "and the filesystem has a mount point" do
        let(:dev_name) { "/dev/sda2" }

        it "returns the filesystem mount point" do
          expect(subject.mount_point).to eq(device.filesystem.mount_point)
        end
      end

      context "and the filesystem has no mount point" do
        let(:dev_name) { "/dev/sdb3" }

        it "returns nil" do
          expect(subject.mount_point).to be_nil
        end
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

  describe "#mount_path" do
    context "when the currently editing device has a filesystem" do
      context "and the filesystem has a mount point" do
        let(:dev_name) { "/dev/sda2" }

        it "returns the path of the filesystem mount point" do
          expect(subject.mount_path).to eq("/")
        end
      end

      context "and the filesystem has no mount point" do
        let(:dev_name) { "/dev/sdb3" }

        it "returns nil" do
          expect(subject.mount_path).to be_nil
        end
      end
    end

    context "when the currently editing device has not a filesystem" do
      before do
        allow(device).to receive(:filesystem).and_return(nil)
        allow(subject).to receive(:blk_device).and_return(device)
      end

      it "returns nil" do
        expect(subject.mount_path).to be_nil
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

  describe "#configure_snapper" do
    context "when the currently editing device has a Btrfs filesystem" do
      let(:dev_name) { "/dev/sda2" }

      it "returns the filesystem value for #configure_snapper" do
        expect(controller.configure_snapper).to eq false
        device.filesystem.configure_snapper = true
        expect(controller.configure_snapper).to eq true
      end
    end

    context "when the currently editing device has a no-Btrfs filesystem" do
      let(:dev_name) { "/dev/sdb6" }

      it "returns false" do
        expect(controller.configure_snapper).to eq false
      end
    end

    context "when the currently editing device has no filesystem" do
      let(:dev_name) { "/dev/sdb7" }

      it "returns false" do
        expect(controller.configure_snapper).to eq false
      end
    end
  end

  describe "#configure_snapper=" do
    let(:dev_name) { "/dev/sda2" }

    it "sets #configure_snapper for the current Btrfs filesystem" do
      expect(device.filesystem.configure_snapper).to eq false
      controller.configure_snapper = true
      expect(device.filesystem.configure_snapper).to eq true
      controller.configure_snapper = false
      expect(device.filesystem.configure_snapper).to eq false
    end
  end

  describe "#apply_role" do
    before do
      subject.role_id = role
    end

    let(:role) { nil }

    it "sets encrypt to false" do
      subject.encrypt = true
      subject.apply_role

      expect(subject.encrypt).to eq(false)
    end

    RSpec.shared_examples "default_mount_by" do
      it "sets mount by to the default value" do
        subject.apply_role
        expect(subject.filesystem.mount_point.mount_by)
          .to eq(Y2Storage::StorageManager.instance.default_mount_by)
      end
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
        expect(subject.filesystem.mount_point.path).to eq("swap")
      end

      include_examples "default_mount_by"
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
        expect(subject.filesystem.mount_point.path).to eq("/boot/efi")
      end

      include_examples "default_mount_by"
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
        expect(subject.blk_device.filesystem.mount_point.path).to eq("swap")
      end
    end

    context "when the currently editing device has already a filesystem" do
      before do
        device.filesystem.label = label
        device.filesystem.mount_path = mount_point
        device.filesystem.mount_point.mount_by = mount_by
      end

      let(:mount_point) { "/foo" }
      let(:mount_by) { Y2Storage::Filesystems::MountByType::DEVICE }
      let(:label) { "foo" }

      it "preserves the mount point" do
        subject.new_filesystem(type)
        expect(subject.blk_device.filesystem.mount_point.path).to eq(mount_point)
      end

      it "preserves the mount by property" do
        subject.new_filesystem(type)
        expect(subject.blk_device.filesystem.mount_point.mount_by).to eq(mount_by)
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

  RSpec.shared_context "mount point actions" do
    let(:mount_path) { "/foo" }
    let(:mount_point_options) { { mount_by: mount_by_id, mount_options: mount_options } }
    let(:mount_by_id) { Y2Storage::Filesystems::MountByType::ID }
    let(:mount_options) { ["rw", "minorversion=1"] }
    let(:filesystem) { subject.filesystem }
  end

  RSpec.shared_examples "btrfs subvolumes check" do
    let(:filesystem) { subject.filesystem }

    before do
      allow(Y2Storage::VolumeSpecification).to receive(:for).with(mount_path)
        .and_return(volume_spec)
    end

    it "does not delete the probed subvolumes" do
      subvolumes = filesystem.btrfs_subvolumes
      subject.public_send(testing_method, mount_path, mount_point_options)

      expect(filesystem.btrfs_subvolumes).to include(*subvolumes)
    end

    it "updates the subvolumes mount points" do
      subject.public_send(testing_method, mount_path, mount_point_options)
      mount_points = filesystem.btrfs_subvolumes.map(&:mount_path).compact
      expect(mount_points).to all(start_with(mount_path))
    end

    it "does not change the mount point for special subvolumes" do
      subject.public_send(testing_method, mount_path, mount_point_options)
      expect(filesystem.top_level_btrfs_subvolume.mount_path.to_s).to be_empty
      expect(filesystem.default_btrfs_subvolume.mount_path.to_s).to be_empty
    end

    it "refreshes btrfs subvolumes shadowing" do
      expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
      subject.public_send(testing_method, mount_path, mount_point_options)
    end

    context "and there is spec with specific default btrfs subvolume for the mount point" do
      let(:default_subvolume) { "@" }

      context "and the current default subvolume is the top level" do
        before do
          filesystem.top_level_btrfs_subvolume.set_default_btrfs_subvolume
        end

        it "creates a new default subvolume" do
          subject.public_send(testing_method, mount_path, mount_point_options)

          expect(filesystem.top_level_btrfs_subvolume).to_not eq(filesystem.default_btrfs_subvolume)
          expect(filesystem.default_btrfs_subvolume.path).to eq("@")
        end
      end

      context "and the current default subvolume is probed" do
        context "and the default subvolume spec has the same path" do
          let(:default_subvolume) { "@" }

          it "does not change the default subvolume" do
            initial_default_subvolume = filesystem.default_btrfs_subvolume

            subject.public_send(testing_method, mount_path, mount_point_options)

            expect(filesystem.default_btrfs_subvolume.sid).to eq(initial_default_subvolume.sid)
            expect(filesystem.default_btrfs_subvolume.path).to eq("@")
          end
        end

        context "and the default subvolume spec has a different path" do
          let(:default_subvolume) { "@@" }

          it "does not remove the previous default subvolume" do
            subject.public_send(testing_method, mount_path, mount_point_options)

            expect(filesystem.btrfs_subvolumes).to include(an_object_having_attributes(path: "@"))
          end

          it "creates a new default subvolume" do
            subject.public_send(testing_method, mount_path, mount_point_options)

            expect(filesystem.default_btrfs_subvolume.path).to eq("@@")
          end
        end
      end

      context "and the current default subvolume is not probed" do
        before do
          filesystem.ensure_default_btrfs_subvolume(path: "@@")
        end

        it "removes the previous default subvolume" do
          default_subvolume_sid = filesystem.default_btrfs_subvolume.sid
          subject.public_send(testing_method, mount_path, mount_point_options)

          expect(filesystem.btrfs_subvolumes)
            .to_not include(an_object_having_attributes(sid: default_subvolume_sid))
        end

        it "creates a new default subvolume" do
          subject.public_send(testing_method, mount_path, mount_point_options)

          expect(filesystem.default_btrfs_subvolume.path).to eq("@")
        end
      end
    end

    context "and there is no spec with specific default btrfs subvolume for the mount point" do
      let(:default_subvolume) { nil }

      context "and the current default subvolume is the top level" do
        before do
          filesystem.top_level_btrfs_subvolume.set_default_btrfs_subvolume
        end

        it "does not change the default subvolume" do
          initial_default_subvolume = filesystem.default_btrfs_subvolume

          subject.public_send(testing_method, mount_path, mount_point_options)

          expect(filesystem.default_btrfs_subvolume.sid).to eq(initial_default_subvolume.sid)
          expect(filesystem.default_btrfs_subvolume.path).to eq("")
        end
      end

      context "and the current default subvolume is probed" do
        it "does not change the default subvolume" do
          default_subvolume = filesystem.default_btrfs_subvolume
          subject.public_send(testing_method, mount_path, mount_point_options)

          expect(filesystem.default_btrfs_subvolume.sid).to eq(default_subvolume.sid)
        end
      end

      context "and the current default subvolume is not probed" do
        before do
          filesystem.ensure_default_btrfs_subvolume(path: "@@")
        end

        it "removes the previous not probed default subvolume" do
          expect(filesystem.default_btrfs_subvolume.path).to eq("@@")

          subject.public_send(testing_method, mount_path, mount_point_options)

          expect(filesystem.btrfs_subvolumes).to_not include(an_object_having_attributes(path: "@@"))
        end

        it "sets the top level subvolume as default subvolume" do
          subject.public_send(testing_method, mount_path, mount_point_options)
          expect(filesystem.top_level_btrfs_subvolume).to eq(filesystem.default_btrfs_subvolume)
        end
      end
    end

    context "and it has 'not probed' subvolumes" do
      let(:path) { "@/bar" }

      before do
        filesystem.create_btrfs_subvolume(path, false)
      end

      it "deletes the not probed subvolumes" do
        subject.public_send(testing_method, mount_path, mount_point_options)
        expect(filesystem.find_btrfs_subvolume_by_path(path)).to be_nil
      end
    end

    context "and there are subvolumes defined for the given mount point" do
      let(:subvolumes) { Y2Storage::SubvolSpecification.fallback_list }

      before do
        # Make sure there is no other mount points
        all_filesystems = Y2Storage::MountPoint.all(devicegraph).map(&:filesystem)
        other_filesystems = all_filesystems - [filesystem]
        other_filesystems.each(&:remove_descendants)
      end

      it "adds the proposed subvolumes that do not exist" do
        subject.public_send(testing_method, mount_path, mount_point_options)

        arch_specs = Y2Storage::SubvolSpecification.for_current_arch(subvolumes)
        paths = arch_specs.map { |s| filesystem.btrfs_subvolume_path(s.path) }

        expect(paths.any? { |p| filesystem.find_btrfs_subvolume_by_path(p).nil? }).to be(false)
      end
    end

    context "and there are no subvolumes defined for the given mount point" do
      let(:subvolumes) { nil }

      it "does not add any subvolume" do
        paths = filesystem.btrfs_subvolumes.map(&:path)
        subject.public_send(testing_method, mount_path, mount_point_options)

        expect(filesystem.btrfs_subvolumes.map(&:path) - paths).to be_empty
      end
    end
  end

  RSpec.shared_examples "does nothing" do
    it "does nothing" do
      devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
      subject.public_send(testing_method, mount_path, mount_point_options)

      expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
    end
  end

  describe "#create_mount_point" do
    include_context "mount point actions"

    let(:testing_method) { :create_mount_point }

    context "when the currently editing device has no filesystem" do
      let(:dev_name) { "/dev/sdb7" }

      include_examples "does nothing"
    end

    context "when the currently editing device has filesystem" do
      let(:dev_name) { "/dev/sdd1" }

      context "and the filesystem already has a mount point" do
        before do
          device.filesystem.mount_path = "/bar"
        end

        include_examples "does nothing"
      end

      context "and the filesystem has no a mount point" do
        before do
          device.filesystem.remove_mount_point
        end

        let(:fs_type) { Y2Storage::Filesystems::Type::EXT4 }

        it "creates a mount point for the filesystem with the given values" do
          device.remove_descendants
          device.create_filesystem(fs_type)

          subject.create_mount_point(mount_path, mount_point_options)

          expect(filesystem.mount_point).to_not be_nil
          expect(filesystem.mount_point.path).to eq(mount_path)
          expect(filesystem.mount_point.mount_by).to eq(mount_by_id)
          expect(filesystem.mount_point.mount_options).to eq(mount_options)
        end

        context "and no mount options are given" do
          let(:mount_options) { nil }

          it "creates a mount point with default mount options" do
            device.remove_descendants
            device.create_filesystem(fs_type)

            subject.create_mount_point(mount_path, mount_point_options)

            expect(filesystem.mount_point.mount_options).to_not be_empty
            expect(filesystem.mount_point.mount_options).to eq(fs_type.default_mount_options)
          end
        end

        context "and the filesystem is btrfs" do
          let(:dev_name) { "/dev/sda2" }

          include_examples "btrfs subvolumes check"
        end
      end
    end
  end

  describe "#update_mount_point" do
    include_context "mount point actions"

    let(:testing_method) { :update_mount_point }

    context "when the currently editing device has no filesystem" do
      let(:dev_name) { "/dev/sdb7" }

      include_examples "does nothing"
    end

    context "when the currently editing device has filesystem" do
      let(:dev_name) { "/dev/sdd1" }

      context "and the filesystem has no mount point" do
        before do
          device.filesystem.remove_mount_point
        end

        include_examples "does nothing"
      end

      context "and the filesystem has a mount point" do
        before do
          device.filesystem.mount_path = fs_mount_path
        end

        context "and the filesystem mount point path is equal to the given path" do
          let(:fs_mount_path) { mount_path }

          let(:mount_path) { "/bar" }

          context "and no mount point options are given" do
            let(:mount_point_options) { nil }

            include_examples "does nothing"
          end

          context "and mount point options are given" do
            before do
              device.remove_descendants
              device.create_filesystem(fs_type)
              device.filesystem.mount_path = fs_mount_path
            end

            let(:fs_type) { Y2Storage::Filesystems::Type::EXT4 }

            it "updates the filesystem mount point options" do
              mount_point_sid = filesystem.mount_point.sid

              subject.update_mount_point(mount_path, mount_point_options)

              expect(filesystem.mount_point.sid).to eq(mount_point_sid)
              expect(filesystem.mount_point.mount_by).to eq(mount_by_id)
              expect(filesystem.mount_point.mount_options).to eq(mount_options)
            end

            it "does not change the mount path" do
              path = filesystem.mount_point.path
              subject.update_mount_point(mount_path, mount_point_options)

              expect(filesystem.mount_point.path).to eq(path)
            end
          end
        end

        context "and the filesystem mount point path is not equal to the given path" do
          let(:fs_mount_path) { "/foo" }

          let(:mount_path) { "/bar" }

          it "updates the filesystem mount point path" do
            mount_point_sid = filesystem.mount_point.sid
            subject.update_mount_point(mount_path, mount_point_options)

            expect(filesystem.mount_point.sid).to eq(mount_point_sid)
            expect(filesystem.mount_point.path).to eq(mount_path)
          end

          context "and the filesystem is btrfs" do
            let(:dev_name) { "/dev/sda2" }

            include_examples "btrfs subvolumes check"
          end
        end
      end
    end
  end

  describe "#create_or_update_mount_point" do
    include_context "mount point actions"

    let(:testing_method) { :create_or_update_mount_point }

    context "when the currently editing device has no filesystem" do
      let(:dev_name) { "/dev/sdb7" }

      include_examples "does nothing"
    end

    context "when the currently editing device has filesystem" do
      let(:dev_name) { "/dev/sdb7" }

      before do
        device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
      end

      context "and the filesystem has no mount point" do
        it "creates a new mount point" do
          expect(subject).to receive(:create_mount_point).with(mount_path, mount_point_options)
          subject.create_or_update_mount_point(mount_path, mount_point_options)
        end
      end

      context "and the filesystem already has a mount point" do
        before do
          device.filesystem.create_mount_point("/foo")
        end

        it "updates the filesystem mount point" do
          expect(subject).to receive(:update_mount_point).with(mount_path, mount_point_options)
          subject.create_or_update_mount_point(mount_path, mount_point_options)
        end
      end
    end
  end

  describe "#remove_mount_point" do
    RSpec.shared_examples "does not remove" do
      it "does nothing" do
        devicegraph = Y2Partitioner::DeviceGraphs.instance.current.dup
        subject.remove_mount_point

        expect(devicegraph).to eq(Y2Partitioner::DeviceGraphs.instance.current)
      end
    end

    context "when the currently editing device has no filesystem" do
      let(:dev_name) { "/dev/sdb7" }

      include_examples "does not remove"
    end

    context "when the currently editing device has filesystem" do
      let(:dev_name) { "/dev/sdb7" }

      before do
        device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
      end

      context "and the filesystem has no mount point" do
        include_examples "does not remove"
      end

      context "and the filesystem already has a mount point" do
        before do
          device.filesystem.create_mount_point("/foo")
        end

        it "removes the filesystem mount point" do
          subject.remove_mount_point
          expect(subject.filesystem.mount_point).to be_nil
        end

        it "refreshes btrfs subvolumes shadowing" do
          expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
          subject.remove_mount_point
        end
      end
    end
  end

  describe "#restore_mount_point" do
    include_context "mount point actions"

    let(:testing_method) { :restore_mount_point }

    context "when the currently editing device has no filesystem" do
      let(:dev_name) { "/dev/sdb7" }

      include_examples "does nothing"
    end

    context "when the currently editing device has filesystem" do
      let(:dev_name) { "/dev/sdd1" }

      context "and the filesystem has a mount point" do
        before do
          device.filesystem.mount_path = fs_mount_path
        end

        let(:fs_mount_path) { "/foo" }

        it "removes the filesystem mount point" do
          mount_point_sid = filesystem.mount_point.sid
          subject.restore_mount_point(mount_path, mount_point_options)
          expect(devicegraph.find_device(mount_point_sid)).to be_nil
        end

        context "and the given mount path is empty" do
          let(:mount_path) { "" }

          it "does not create a new mount point" do
            subject.restore_mount_point(mount_path, mount_point_options)
            expect(filesystem.mount_point).to be_nil
          end
        end

        context "and the given mount path is nil" do
          let(:mount_path) { nil }

          it "does not create a new mount point" do
            subject.restore_mount_point(mount_path, mount_point_options)
            expect(filesystem.mount_point).to be_nil
          end
        end

        context "and a mount path is given" do
          let(:mount_path) { "/foo" }

          let(:fs_type) { Y2Storage::Filesystems::Type::EXT4 }

          it "creates a mount point for the filesystem with the given values" do
            device.remove_descendants
            device.create_filesystem(fs_type)
            device.filesystem.mount_path = fs_mount_path

            subject.restore_mount_point(mount_path, mount_point_options)

            expect(filesystem.mount_point).to_not be_nil
            expect(filesystem.mount_point.path).to eq(mount_path)
            expect(filesystem.mount_point.mount_by).to eq(mount_by_id)
            expect(filesystem.mount_point.mount_options).to eq(mount_options)
          end

          context "when no mount options are given" do
            let(:mount_options) { nil }

            before do
              device.remove_descendants
              device.create_filesystem(fs_type)
              device.filesystem.mount_path = fs_mount_path
            end

            it "does not set default mount options" do
              subject.restore_mount_point(mount_path, mount_point_options)
              expect(filesystem.mount_point.mount_options).to_not eq(fs_type.default_mount_options)
            end
          end

          context "and the filesystem is btrfs" do
            let(:dev_name) { "/dev/sda2" }

            include_examples "btrfs subvolumes check"
          end
        end
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

  describe "#format_options_supported?" do
    context "when the currently editing device has no filesystem" do
      let(:dev_name) { "/dev/sdb7" }

      it "returns false" do
        expect(controller.format_options_supported?).to eq false
      end
    end

    context "when the currently editing device has a filesystem" do
      context "that is a preexisting Btrfs one" do
        let(:dev_name) { "/dev/sda2" }

        it "returns false" do
          expect(controller.format_options_supported?).to eq false
        end
      end

      context "that is a preexisting no-Btrfs one" do
        let(:dev_name) { "/dev/sdb5" }

        it "returns false" do
          expect(controller.format_options_supported?).to eq false
        end
      end

      context "that is a new (to be created) Btrfs" do
        it "returns false" do
          device.remove_descendants
          device.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)

          expect(controller.format_options_supported?).to eq false
        end
      end

      context "that is a new (to be created) no-Btrfs" do
        it "returns true" do
          device.remove_descendants
          device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)

          expect(controller.format_options_supported?).to eq true
        end
      end
    end
  end

  describe "#snapshots_supported?" do
    before { allow(Yast::Mode).to receive(:installation).and_return inst_mode }
    let(:inst_mode) { false }

    context "when the currently editing device has no filesystem" do
      let(:dev_name) { "/dev/sdb7" }

      context "in installation mode" do
        let(:inst_mode) { true }

        it "returns false" do
          expect(controller.snapshots_supported?).to eq false
        end
      end

      context "in normal mode" do
        let(:inst_mode) { false }

        it "returns false" do
          expect(controller.snapshots_supported?).to eq false
        end
      end
    end

    context "when the currently editing device has a filesystem" do
      context "that is a preexisting Btrfs one" do
        let(:dev_name) { "/dev/sda2" }

        context "in installation mode" do
          let(:inst_mode) { true }

          it "returns false" do
            expect(controller.snapshots_supported?).to eq false
          end
        end

        context "in normal mode" do
          let(:inst_mode) { false }

          it "returns false" do
            expect(controller.snapshots_supported?).to eq false
          end
        end
      end

      context "that is a preexisting no-Btrfs one" do
        let(:dev_name) { "/dev/sdb5" }

        context "in installation mode" do
          let(:inst_mode) { true }

          it "returns false" do
            expect(controller.snapshots_supported?).to eq false
          end
        end

        context "in normal mode" do
          let(:inst_mode) { false }

          it "returns false" do
            expect(controller.snapshots_supported?).to eq false
          end
        end
      end

      context "that is a new (to be created) Btrfs" do
        before do
          device.remove_descendants
          device.create_filesystem(Y2Storage::Filesystems::Type::BTRFS)
          device.filesystem.mount_path = mntpnt
        end

        context "if is going to be mounted as root" do
          let(:mntpnt) { "/" }

          context "in installation mode" do
            let(:inst_mode) { true }

            it "returns true" do
              expect(controller.snapshots_supported?).to eq true
            end
          end

          context "in normal mode" do
            let(:inst_mode) { false }

            it "returns false" do
              expect(controller.snapshots_supported?).to eq false
            end
          end
        end

        context "if is not going to be mounted as root" do
          let(:mntpnt) { "/var" }

          context "in installation mode" do
            let(:inst_mode) { true }

            it "returns false" do
              expect(controller.snapshots_supported?).to eq false
            end
          end

          context "in normal mode" do
            let(:inst_mode) { false }

            it "returns false" do
              expect(controller.snapshots_supported?).to eq false
            end
          end
        end
      end

      context "that is a new (to be created) no-Btrfs" do
        before do
          device.remove_descendants
          device.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
          device.filesystem.mount_path = mntpnt
        end

        context "if is going to be mounted as root" do
          let(:mntpnt) { "/" }

          context "in installation mode" do
            let(:inst_mode) { true }

            it "returns false" do
              expect(controller.snapshots_supported?).to eq false
            end
          end

          context "in normal mode" do
            let(:inst_mode) { false }

            it "returns false" do
              expect(controller.snapshots_supported?).to eq false
            end
          end
        end

        context "if is not going to be mounted as root" do
          let(:mntpnt) { "/var" }

          context "in installation mode" do
            let(:inst_mode) { true }

            it "returns false" do
              expect(controller.snapshots_supported?).to eq false
            end
          end

          context "in normal mode" do
            let(:inst_mode) { false }

            it "returns false" do
              expect(controller.snapshots_supported?).to eq false
            end
          end
        end
      end
    end
  end

  describe "#mount_paths" do
    let(:storage_arch) { instance_double("::Storage::Arch") }

    before do
      allow(Y2Storage::StorageManager.instance.storage).to receive(:arch).and_return(storage_arch)
      allow(storage_arch).to receive(:s390?).and_return s390
      allow(storage_arch).to receive(:efiboot?).and_return efi
      allow(Yast::Stage).to receive(:initial).and_return installation
    end

    let(:system_mountpoints) { ["/", "/var", "/opt"] }
    let(:additional_mountpoints) { ["/home", "/srv", "/tmp", "/usr/local"] }

    context "if no mount points are assigned so far" do
      let(:scenario) { "windows-linux-multiboot-pc" }
      before do
        devicegraph.filesystems.each do |fs|
          fs.remove_mount_point unless fs.mount_point.nil?
        end
      end

      RSpec.shared_examples "always included" do
        it "includes the additional mount points" do
          expect(controller.mount_paths).to include(*additional_mountpoints)
        end

        context "if the filesystem is of type SWAP" do
          let(:dev_name) { "/dev/sda2" }

          it "includes 'swap' as the first element of the list" do
            expect(controller.mount_paths.first).to eq "swap"
          end
        end

        context "if the filesystem is not of type SWAP" do
          let(:dev_name) { "/dev/sda1" }

          it "does not include 'swap'" do
            expect(controller.mount_paths).to_not include("swap")
          end
        end
      end

      context "during installation" do
        let(:installation) { true }

        context "in a s390 system" do
          let(:s390) { true }
          let(:efi) { false }

          it "includes the system mount points" do
            expect(controller.mount_paths).to include(*system_mountpoints)
          end

          it "includes /boot and /boot/zipl" do
            expect(controller.mount_paths).to include("/boot", "/boot/zipl")
          end

          it "does not include /boot/efi" do
            expect(controller.mount_paths).to_not include("/boot/efi")
          end

          include_examples "always included"
        end

        context "in a non-s390 system" do
          let(:s390) { false }

          context "with EFI boot" do
            let(:efi) { true }

            it "includes the system mount points" do
              expect(controller.mount_paths).to include(*system_mountpoints)
            end

            it "includes /boot and /boot/efi" do
              expect(controller.mount_paths).to include("/boot", "/boot/efi")
            end

            it "does not include /boot/zipl" do
              expect(controller.mount_paths).to_not include("/boot/zipl")
            end

            include_examples "always included"
          end

          context "with no EFI" do
            let(:efi) { false }

            it "includes the system mount points" do
              expect(controller.mount_paths).to include(*system_mountpoints)
            end

            it "includes /boot" do
              expect(controller.mount_paths).to include("/boot")
            end

            it "does not include /boot/zipl or /boot/efi" do
              expect(controller.mount_paths).to_not include("/boot/efi")
              expect(controller.mount_paths).to_not include("/boot/zipl")
            end

            include_examples "always included"
          end
        end
      end

      context "in an installed system" do
        let(:installation) { false }

        context "if it's a s390 system" do
          let(:s390) { true }
          let(:efi) { false }

          it "does not include the system mount points" do
            system_mountpoints.each do |mp|
              expect(controller.mount_paths).to_not include mp
            end
          end

          it "does not include /boot, /boot/efi or /boot/zipl" do
            expect(controller.mount_paths).to_not include("/boot")
            expect(controller.mount_paths).to_not include("/boot/zipl")
            expect(controller.mount_paths).to_not include("/boot/efi")
          end

          include_examples "always included"
        end

        context "if it's not a s390 system" do
          let(:s390) { false }

          context "with EFI boot" do
            let(:efi) { true }

            it "does not include the system mount points" do
              system_mountpoints.each do |mp|
                expect(controller.mount_paths).to_not include mp
              end
            end

            it "does not include /boot, /boot/efi or /boot/zipl" do
              expect(controller.mount_paths).to_not include("/boot")
              expect(controller.mount_paths).to_not include("/boot/zipl")
              expect(controller.mount_paths).to_not include("/boot/efi")
            end

            include_examples "always included"
          end

          context "with no EFI" do
            let(:efi) { false }

            it "does not include the system mount points" do
              system_mountpoints.each do |mp|
                expect(controller.mount_paths).to_not include mp
              end
            end

            it "does not include /boot, /boot/efi or /boot/zipl" do
              expect(controller.mount_paths).to_not include("/boot")
              expect(controller.mount_paths).to_not include("/boot/zipl")
              expect(controller.mount_paths).to_not include("/boot/efi")
            end

            include_examples "always included"
          end
        end
      end
    end

    context "if some mount points are already taken" do
      let(:scenario) { "mixed_disks" }
      # Let's enforce the temptative presence of /
      let(:installation) { true }
      # Let's enforce the temptative presence of swap
      let(:dev_name) { "/dev/sdb1" }
      # These two are not much relevant; swap, /home and / should be there in
      # any combination
      let(:s390) { false }
      let(:efi) { false }

      it "does not include the already mounted regular paths" do
        expect(controller.mount_paths).to_not include("/")
        expect(controller.mount_paths).to_not include("/home")
      end

      it "includes 'swap' despite it being already used" do
        expect(controller.mount_paths).to include("swap")
      end
    end
  end
end
