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
require "storage"
require "storage/disks_list"
require "storage/partitions_list"
require "storage/filesystems_list"
require "storage/free_disk_spaces_list"
require "storage/refinements/devicegraph_lists"
require "storage/refinements/size_casts"

describe "devices lists" do
  using Yast::Storage::Refinements::DevicegraphLists

  # Just to shorten
  let(:ext4) { ::Storage::FsType_EXT4 }
  let(:ntfs) { ::Storage::FsType_NTFS }
  let(:id_linux) { ::Storage::ID_LINUX }
  let(:id_swap) { ::Storage::ID_SWAP }
  let(:primary) { ::Storage::PartitionType_PRIMARY }

  before do
    fake_scenario("mixed_disks")
  end

  describe "Yast::Storage::DevicesList" do
    describe "#with" do
      it "returns a list of the same class" do
        result = fake_devicegraph.filesystems.with(type: ext4)
        expect(result).to be_a(Yast::Storage::FilesystemsList)
      end

      it "filters by a scalar value" do
        result = fake_devicegraph.filesystems.with(type: ext4)
        expect(result).to contain_exactly(
          an_object_with_fields(label: "root"),
          an_object_with_fields(label: "ubuntu_root")
        )
      end

      it "filters by an array of values" do
        result = fake_devicegraph.filesystems.with(type: [ext4, ntfs])
        expect(result).to contain_exactly(
          an_object_with_fields(label: "root"),
          an_object_with_fields(label: "ubuntu_root"),
          an_object_with_fields(label: "windows"),
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

  describe Yast::Storage::DisksList do
    let(:disks) { fake_devicegraph.disks }

    it "contains all disks by default" do
      expect(disks.size).to eq 3
      expect(described_class.new(fake_devicegraph).size).to eq 3
    end

    describe "#partitions" do
      it "returns a filtered list of partitions" do
        parts_sdb = disks.with(name: "/dev/sdb").partitions
        parts_sdc = disks.with(name: "/dev/sdc").partitions
        expect(parts_sdb).to be_a Yast::Storage::PartitionsList
        expect(parts_sdb.size).to eq 7
        expect(parts_sdc).to be_a Yast::Storage::PartitionsList
        expect(parts_sdc.size).to eq 0
      end
    end

    describe "#filesystems" do
      it "returns a filtered list of filesystems" do
        fs_sdb = disks.with(name: "/dev/sdb").filesystems
        fs_sdc = disks.with(name: "/dev/sdc").filesystems
        expect(fs_sdb).to be_a Yast::Storage::FilesystemsList
        expect(fs_sdb.size).to eq 5
        expect(fs_sdc).to be_a Yast::Storage::FilesystemsList
        expect(fs_sdc.size).to eq 0
      end
    end

    describe "#free_disk_spaces" do
      it "returns a filtered list of FreeDiskSpace" do
        spaces_all = disks.free_disk_spaces
        spaces_sdc = disks.with(name: "/dev/sdc").free_disk_spaces
        expect(spaces_all).to be_a Yast::Storage::FreeDiskSpacesList
        expect(spaces_all.size).to eq 3
        expect(spaces_sdc).to be_a Yast::Storage::FreeDiskSpacesList
        expect(spaces_sdc.size).to eq 1
      end
    end
  end

  describe Yast::Storage::PartitionsList do
    let(:partitions) { fake_devicegraph.partitions }

    it "contains all partitions by default" do
      expect(partitions.size).to eq 9
      expect(described_class.new(fake_devicegraph).size).to eq 9
    end

    describe "#filesystems" do
      it "returns a filtered list of filesystems" do
        parts_sda = partitions.with {|p| p.name.start_with? "/dev/sda" }
        parts_sdb = partitions.with {|p| p.name.start_with? "/dev/sdb" }
        expect(parts_sda.filesystems).to be_a Yast::Storage::FilesystemsList
        expect(parts_sda.filesystems.size).to eq 2
        expect(parts_sdb.filesystems).to be_a Yast::Storage::FilesystemsList
        expect(parts_sdb.filesystems.size).to eq 5
      end
    end
  end

  describe Yast::Storage::FilesystemsList do
    let(:filesystems) { fake_devicegraph.filesystems }

    it "contains all filesystems by default" do
      expect(filesystems.size).to eq 7
      expect(described_class.new(fake_devicegraph).size).to eq 7
    end
  end

  describe Yast::Storage::FreeDiskSpacesList do
    using Yast::Storage::Refinements::SizeCasts

    let(:spaces) { fake_devicegraph.free_disk_spaces }

    it "contains all spaces by default" do
      expect(spaces.size).to eq 3
      expect(described_class.new(fake_devicegraph).size).to eq 3
    end

    describe "#disk_size" do
      it "returns to sum of all the spaces sizes" do
        expect(spaces.disk_size).to eq 602.GiB
      end
    end
  end
end
