#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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
require "y2storage"

describe "devices lists" do
  using Y2Storage::Refinements::DevicegraphLists

  # Just to shorten
  let(:ext4) { ::Storage::FsType_EXT4 }
  let(:ntfs) { ::Storage::FsType_NTFS }
  let(:id_linux) { ::Storage::ID_LINUX }
  let(:id_swap) { ::Storage::ID_SWAP }
  let(:primary) { ::Storage::PartitionType_PRIMARY }

  subject(:full_list) { described_class.new(fake_devicegraph) }

  before do
    fake_scenario(scenario)
  end
  let(:scenario) { "mixed_disks" }

  describe "Y2Storage::DevicesLists::Base" do
    describe "#with" do
      it "returns a list of the same class" do
        result = fake_devicegraph.filesystems.with(type: ext4)
        expect(result).to be_a(Y2Storage::DevicesLists::FilesystemsList)
      end

      it "filters by a scalar value" do
        result = fake_devicegraph.filesystems.with(type: ext4)
        expect(result).to contain_exactly(
          an_object_with_fields(label: "root"),
          an_object_with_fields(label: "ubuntu_root")
        )
      end

      it "filters by nil values" do
        # rubocop:disable Style/ClassAndModuleChildren

        # In the moment of writing, there are no attributes that can return nil
        # and that are easy to mock, let's invent one
        class Y2Storage::FreeDiskSpace
          def partition_name
            disk_name == "/dev/sdb" ? "/dev/sdb4" : nil
          end
        end
        # rubocop:enable Style/ClassAndModuleChildren

        result = fake_devicegraph.free_disk_spaces.with(partition_name: nil)
        expect(result).to contain_exactly(
          an_object_with_fields(disk_name: "/dev/sda"),
          an_object_with_fields(disk_name: "/dev/sdc")
        )
      end

      it "considers not found libstorage attributes as nil" do
        result = fake_devicegraph.partitions.with(filesystem: nil)
        expect(result).to contain_exactly(
          an_object_with_fields(name: "/dev/sdb4"),
          an_object_with_fields(name: "/dev/sdb7")
        )
      end

      it "filters by an array of values" do
        result = fake_devicegraph.filesystems.with(type: [ext4, ntfs])
        expect(result).to contain_exactly(
          an_object_with_fields(label: "root"),
          an_object_with_fields(label: "ubuntu_root"),
          an_object_with_fields(label: "windows")
        )
      end

      it "filters by another list of values" do
        filesystems = fake_devicegraph.filesystems.with(type: [ext4, ntfs])
        result = fake_devicegraph.partitions.with(filesystem: filesystems)
        expect(result).to contain_exactly(
          an_object_with_fields(name: "/dev/sda1"),
          an_object_with_fields(name: "/dev/sdb3"),
          an_object_with_fields(name: "/dev/sda2")
        )
      end

      it "filters by any combination of scalars and lists" do
        result = fake_devicegraph.partitions.with(id: [id_swap, id_linux], type: primary)
        expect(result).to contain_exactly(
          an_object_with_fields(name: "/dev/sda2"),
          an_object_with_fields(name: "/dev/sdb1"),
          an_object_with_fields(name: "/dev/sdb2"),
          an_object_with_fields(name: "/dev/sdb3")
        )
      end

      it "filters by block" do
        result = fake_devicegraph.filesystems.with do |fs|
          fs.mountpoints.first == "/"
        end
        expect(result).to contain_exactly(
          an_object_with_fields(label: "root")
        )
      end
    end

    describe "#size" do
      it "returns the number of elements" do
        expect(fake_devicegraph.disks.size).to eq 3
      end
    end

    describe "#to_a" do
      it "returns an array with the elements" do
        array = fake_devicegraph.disks.to_a
        expect(array).to be_an Array
        expect(array.size).to eq 3
      end
    end

    describe "#empty?" do
      it "returns true if no elements are found" do
        disks = fake_devicegraph.disks.with(name: "/dev/sdc")
        expect(disks.partitions.empty?).to eq true
      end

      it "returns false if some element is found" do
        disks = fake_devicegraph.disks.with(name: "/dev/sda")
        expect(disks.partitions.empty?).to eq false
      end
    end
  end

  describe Y2Storage::DevicesLists::DisksList do
    let(:disks) { fake_devicegraph.disks }

    it "contains all disks by default" do
      expect(disks.size).to eq 3
      expect(.size).to eq 3
    end

    describe "#partitions" do
      it "returns a filtered list of partitions" do
        parts_sdb = disks.with(name: "/dev/sdb").partitions
        parts_sdc = disks.with(name: "/dev/sdc").partitions
        expect(parts_sdb).to be_a Y2Storage::DevicesLists::PartitionsList
        expect(parts_sdb.size).to eq 7
        expect(parts_sdc).to be_a Y2Storage::DevicesLists::PartitionsList
        expect(parts_sdc.size).to eq 0
      end
    end

    describe "#filesystems" do
      it "returns a filtered list of filesystems" do
        fs_sdb = disks.with(name: "/dev/sdb").filesystems
        fs_sdc = disks.with(name: "/dev/sdc").filesystems
        expect(fs_sdb).to be_a Y2Storage::DevicesLists::FilesystemsList
        expect(fs_sdb.size).to eq 5
        expect(fs_sdc).to be_a Y2Storage::DevicesLists::FilesystemsList
        expect(fs_sdc.size).to eq 0
      end
    end

    describe "#free_disk_spaces" do
      it "returns a filtered list of FreeDiskSpace" do
        spaces_all = disks.free_disk_spaces
        spaces_sdc = disks.with(name: "/dev/sdc").free_disk_spaces
        expect(spaces_all).to be_a Y2Storage::DevicesLists::FreeDiskSpacesList
        expect(spaces_all.size).to eq 3
        expect(spaces_sdc).to be_a Y2Storage::DevicesLists::FreeDiskSpacesList
        expect(spaces_sdc.size).to eq 1
      end
    end
  end

  describe Y2Storage::DevicesLists::PartitionsList do
    let(:partitions) { fake_devicegraph.partitions }

    it "contains all partitions by default" do
      expect(partitions.size).to eq 9
      expect(full_list.size).to eq 9
    end

    describe "#filesystems" do
      it "returns a filtered list of filesystems" do
        parts_sda = partitions.with { |p| p.name.start_with? "/dev/sda" }
        parts_sdb = partitions.with { |p| p.name.start_with? "/dev/sdb" }
        expect(parts_sda.filesystems).to be_a Y2Storage::DevicesLists::FilesystemsList
        expect(parts_sda.filesystems.size).to eq 2
        expect(parts_sdb.filesystems).to be_a Y2Storage::DevicesLists::FilesystemsList
        expect(parts_sdb.filesystems.size).to eq 5
      end
    end
  end

  describe Y2Storage::DevicesLists::FilesystemsList do
    let(:filesystems) { fake_devicegraph.filesystems }

    it "contains all filesystems by default" do
      expect(filesystems.size).to eq 7
      expect(full_list.size).to eq 7
    end
  end

  describe Y2Storage::DevicesLists::FreeDiskSpacesList do
    using Y2Storage::Refinements::SizeCasts

    let(:spaces) { fake_devicegraph.free_disk_spaces }

    it "contains all spaces by default" do
      expect(spaces.size).to eq 3
      expect(full_list.size).to eq 3
    end

    describe "#disk_size" do
      it "returns to sum of all the spaces sizes" do
        # Free space in /dev/sdb is 90GiB-1MiB because that 1MiB is filled by
        # the partition table. Same happens in /dev/sdc (500GiB-1MiB)
        expect(spaces.disk_size).to eq(592.GiB - 2.MiB)
      end
    end
  end

  describe Y2Storage::DevicesLists::LvmVgsList do
    let(:scenario) { "lvm-two-vgs" }
    let(:vgs) { fake_devicegraph.vgs }

    it "contains all volume groups by default" do
      expect(vgs.size).to eq 2
      expect(full_list.size).to eq 2
    end

    describe "#lvm_pvs" do
      it "returns a filtered list of physical volumes" do
        pvs_vg0 = vgs.with(vg_name: "vg0").lvm_pvs
        pvs_vg1 = vgs.with(vg_name: "vg1").lvm_pvs
        expect(pvs_vg0).to be_a Y2Storage::DevicesLists::LvmPvsList
        expect(pvs_vg0.size).to eq 1
        expect(pvs_vg1).to be_a Y2Storage::DevicesLists::LvmPvsList
        expect(pvs_vg1.size).to eq 2
      end
    end

    describe "#lvm_lvs" do
      it "returns a filtered list of logical volumes" do
        lvs_vg0 = vgs.with(vg_name: "vg0").lvm_lvs
        lvs_vg1 = vgs.with(vg_name: "vg1").lvm_lvs
        expect(lvs_vg0).to be_a Y2Storage::DevicesLists::LvmLvsList
        expect(lvs_vg0.size).to eq 2
        expect(lvs_vg1).to be_a Y2Storage::DevicesLists::LvmLvsList
        expect(lvs_vg1.size).to eq 1
      end
    end
  end

  describe Y2Storage::DevicesLists::LvmPvsList do
    let(:scenario) { "lvm-two-vgs" }
    let(:pvs) { fake_devicegraph.pvs }

    it "contains all physical volumes by default" do
      expect(pvs.size).to eq 3
      expect(full_list.size).to eq 3
    end
  end

  describe Y2Storage::DevicesLists::LvmLvsList do
    let(:scenario) { "lvm-two-vgs" }
    let(:lvs) { fake_devicegraph.lvs }

    it "contains all logical volumes by default" do
      expect(lvs.size).to eq 3
      expect(full_list.size).to eq 3
    end
  end
end
