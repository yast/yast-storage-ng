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

require_relative "test_helper"
require "y2storage"
require "y2partitioner/actions/controllers/filesystem"
require "y2partitioner/actions/controllers/lvm_vg"

describe "Creating and deleting filesystems in a block device" do
  before { devicegraph_stub("trivial_lvm_and_other_partitions") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  subject(:partition) { current_graph.find_by_name(dev_name) }
  subject(:vg) { current_graph.find_by_name("/dev/vg0") }

  let(:new_fs_type) { Y2Storage::Filesystems::Type::EXT2 }
  let(:btrfs_type) { Y2Storage::Filesystems::Type::BTRFS }
  let(:lvm_id) { Y2Storage::PartitionId::LVM }
  let(:linux_id) { Y2Storage::PartitionId::LINUX }
  let(:fs_controller) do
    Y2Partitioner::Actions::Controllers::Filesystem.new(partition, "The title")
  end
  let(:vg_controller) do
    Y2Partitioner::Actions::Controllers::LvmVg.new(vg: vg)
  end

  RSpec.shared_examples "empty partition" do
    context "using the 'Do not format device' option" do
      it "results in an empty partition (no descendants)" do
        # Open the 'Edit' wizard and click on 'Format device'
        # and ensure the new filesystem has been created
        fs_controller.new_filesystem(new_fs_type)
        expect(partition.filesystem.type).to eq new_fs_type

        # Then click on 'Do not format device'
        fs_controller.dont_format

        expect(partition.descendants).to be_empty
      end
    end

    context "adding the partition as PV and removing it afterwards" do
      include_examples "lvm keeps a newly added filesystem"

      it "leaves the partition empty again" do
        # Ensure there are no descendants at the beginning
        expect(partition.descendants).to be_empty

        # Add the device and ensure it was added
        vg_controller.add_device(partition)
        expect(partition.lvm_pv.lvm_vg).to eq vg

        vg_controller.remove_device(partition)
        expect(partition.descendants).to be_empty
      end
    end
  end

  RSpec.shared_examples "lvm keeps a newly added filesystem" do
    context "having created a new filesystem before" do
      before do
        # Use the edit dialog to format the partition
        fs_controller.new_filesystem(new_fs_type)
        fs_controller.encrypt = false
        fs_controller.finish
      end

      it "keeps the new filesystem" do
        # Ensure the new filesystem was properly created
        initial_sid = partition.filesystem.sid
        expect(partition.filesystem.type).to eq new_fs_type
        expect(partition.id).to eq linux_id

        # Add the device and ensure it was added
        vg_controller.add_device(partition)
        expect(partition.filesystem).to be_nil
        expect(partition.lvm_pv.lvm_vg).to eq vg
        expect(partition.id).to eq lvm_id

        vg_controller.remove_device(partition)

        expect(partition.filesystem.sid).to eq initial_sid
        expect(partition.filesystem.type).to eq new_fs_type
        expect(partition.id).to eq linux_id
      end
    end
  end

  # Open the 'Edit' wizard, click on 'Format device', uncheck 'Encrypt
  # Device' and ensure the new filesystem was created
  def format_partition
    fs_controller.new_filesystem(new_fs_type)
    fs_controller.encrypt = false
    expect(partition.filesystem.type).to eq new_fs_type
    expect(partition.encrypted?).to eq false
  end

  # Checks for the filesystem, the partition id and all the subvolumes
  def expect_fs_and_subvolumes(fs_sid, subvol_sids, subvol_paths)
    filesystem = partition.filesystem
    subvolumes = filesystem.btrfs_subvolumes

    expect(partition.id).to eq linux_id

    expect(filesystem.sid).to eq fs_sid
    expect(filesystem.type).to eq btrfs_type

    expect(subvolumes.map(&:sid)).to contain_exactly(*subvol_sids)
    expect(subvolumes.map(&:path)).to contain_exactly(*subvol_paths)
  end

  context "for a new device (not in the system devicegraph)" do
    let(:dev_name) { "/dev/sda7" }

    before do
      sda = current_graph.find_by_name("/dev/sda")
      sda.partition_table.create_partition(
        dev_name,
        sda.partition_table.unused_partition_slots.first.region,
        Y2Storage::PartitionType::PRIMARY
      )
    end

    include_examples "empty partition"
  end

  context "for an existing empty partition" do
    let(:dev_name) { "/dev/sda2" }

    include_examples "empty partition"
  end

  context "for an existing encrypted but not formatted partition" do
    let(:dev_name) { "/dev/sda3" }

    context "using the 'Do not format device' option" do
      it "keeps the original encryption without adding anything else" do
        luks_sid = partition.encryption.sid

        # Click on 'Format device' and ensure the new filesystem was created
        format_partition

        # Then click on 'Do not format device'
        fs_controller.dont_format

        expect(partition.filesystem).to be_nil
        expect(partition.encryption.sid).to eq luks_sid
      end
    end

    context "adding the partition as PV and removing it afterwards" do
      include_examples "lvm keeps a newly added filesystem"

      it "keeps the original encryption without adding anything else" do
        luks_sid = partition.encryption.sid

        # Add the device and ensure it was added
        vg_controller.add_device(partition)
        expect(partition.lvm_pv.lvm_vg).to eq vg

        # Remove it again
        vg_controller.remove_device(partition)

        expect(partition.filesystem).to be_nil
        expect(partition.encryption.sid).to eq luks_sid
      end
    end
  end

  context "for an existing encrypted Btrfs partition not mounted initially" do
    let(:dev_name) { "/dev/sda4" }

    context "using the 'Do not format device' option" do
      it "keeps the original encryption, filesystem and subvolumes" do
        luks_sid = partition.encryption.sid
        fs_sid = partition.filesystem.sid
        subvol_sids = partition.filesystem.btrfs_subvolumes.map(&:sid)

        # Click on 'Format device' and ensure the new filesystem was created
        format_partition

        # Then click on 'Do not format device'
        fs_controller.dont_format

        expect(partition.encryption.sid).to eq luks_sid
        expect(partition.filesystem.label).to eq "crypted_btrfs"
        expect_fs_and_subvolumes(fs_sid, subvol_sids, ["", "subvol4_1", "subvol4_1/sub"])
      end
    end

    context "adding the partition as PV and removing it afterwards" do
      include_examples "lvm keeps a newly added filesystem"

      it "keeps the original encryption, filesystem and subvolumes" do
        luks_sid = partition.encryption.sid
        fs_sid = partition.filesystem.sid
        subvol_sids = partition.filesystem.btrfs_subvolumes.map(&:sid)

        # Add the device and ensure it was added
        vg_controller.add_device(partition)
        expect(partition.lvm_pv.lvm_vg).to eq vg

        # Remove it again
        vg_controller.remove_device(partition)

        expect(partition.encryption.sid).to eq luks_sid
        expect(partition.filesystem.label).to eq "crypted_btrfs"
        expect_fs_and_subvolumes(fs_sid, subvol_sids, ["", "subvol4_1", "subvol4_1/sub"])
      end
    end
  end

  context "for an initially mounted Btrfs partition" do
    let(:dev_name) { "/dev/sda5" }

    context "using the 'Do not format device' option" do
      it "keeps the original filesystem and subvolumes" do
        fs_sid = partition.filesystem.sid
        subvol_sids = partition.filesystem.btrfs_subvolumes.map(&:sid)

        # Click on 'Format device' and ensure a new filesystem was created
        format_partition

        # Then click on 'Do not format device'
        fs_controller.dont_format

        expect(partition.filesystem.label).to eq "mounted_btrfs"
        expect_fs_and_subvolumes(fs_sid, subvol_sids, ["", "subvol5_1"])
      end

      it "does not restore the MountPoint object" do
        mountpoint_sid = partition.filesystem.mount_point.sid

        # Click on 'Format device' and ensure a new filesystem was created
        format_partition

        # Then click on 'Do not format device'
        fs_controller.dont_format

        expect(partition.filesystem.mount_point.sid).to_not eq mountpoint_sid
      end
    end

    context "adding the partition as PV and removing it afterwards" do
      include_examples "lvm keeps a newly added filesystem"

      it "keeps the original filesystem and subvolumes" do
        fs_sid = partition.filesystem.sid
        subvol_sids = partition.filesystem.btrfs_subvolumes.map(&:sid)

        # Add the device and ensure it was added
        vg_controller.add_device(partition)
        expect(partition.lvm_pv.lvm_vg).to eq vg

        # Remove it again
        vg_controller.remove_device(partition)

        expect(partition.filesystem.label).to eq "mounted_btrfs"
        expect_fs_and_subvolumes(fs_sid, subvol_sids, ["", "subvol5_1"])
      end

      it "does not restore the original the mount point" do
        # Add the device and ensure it was added
        vg_controller.add_device(partition)
        expect(partition.lvm_pv.lvm_vg).to eq vg

        # Remove it again
        vg_controller.remove_device(partition)

        expect(partition.filesystem.mount_point).to be_nil
      end
    end
  end

  context "for a logical volume" do
    subject(:lv) { current_graph.find_by_name(dev_name) }
    let(:dev_name) { "/dev/vg0/lv1" }

    context "using the 'Do not format device' option" do
      it "keeps the original filesystem without restoring the MountPoint object" do
        fs_sid = lv.filesystem.sid
        mountpoint_sid = lv.filesystem.mount_point.sid

        # Click on 'Format device' and ensure a new filesystem was created
        fs_controller.new_filesystem(new_fs_type)
        expect(lv.filesystem.type).to eq new_fs_type

        # Then click on 'Do not format device'
        fs_controller.dont_format

        expect(lv.filesystem.sid).to eq fs_sid
        expect(lv.filesystem.type).to eq btrfs_type
        expect(lv.filesystem.mount_point.sid).to_not eq mountpoint_sid
      end
    end
  end
end
