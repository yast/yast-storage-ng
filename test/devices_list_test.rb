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

    describe "#+" do
      it "raises an error if the lists are of a different type" do
        disks = fake_devicegraph.disks
        partitions = fake_devicegraph.partitions
        expect { disks + partitions }.to raise_error TypeError
      end

      it "raises a new list" do
        disks_a = fake_devicegraph.disks.with(name: "/dev/sda")
        disks_b = fake_devicegraph.disks.with(name: "/dev/sdb")
        expect(disks_a + disks_b).to be_a(Y2Storage::DevicesLists::DisksList)
      end

      it "returns an equivalent object if the other list is empty" do
        disks = fake_devicegraph.disks
        no_disks = fake_devicegraph.disks.with(name: "john")
        result = disks + no_disks
        expect(result.to_a).to eq disks.to_a
      end

      it "concatenates elements from both lists in the same order" do
        partitions_a = fake_devicegraph.disks.with(name: "/dev/sda").partitions
        partitions_b = fake_devicegraph.disks.with(name: "/dev/sdb").partitions
        result = partitions_a + partitions_b
        expect(result.to_a).to eq(partitions_a.to_a + partitions_b.to_a)
        result = partitions_b + partitions_a
        expect(result.to_a).to eq(partitions_b.to_a + partitions_a.to_a)
      end

      it "does not remove duplicates" do
        all_disks = fake_devicegraph.disks
        disks = fake_devicegraph.disks.with(name: "/dev/sda")
        result = all_disks + disks
        expect(result.size).to eq 4
      end

      it "does not modify the operands" do
        all_disks = fake_devicegraph.disks
        disks = fake_devicegraph.disks.with(name: "/dev/sda")
        result = all_disks + disks
        expect(result.size).to eq 4
        expect(all_disks.size).to eq 3
        expect(disks.size).to eq 1
      end
    end
  end

  describe Y2Storage::DevicesLists::DisksList do
    let(:disks) { fake_devicegraph.disks }

    it "contains all disks by default" do
      expect(disks.size).to eq 3
      expect(full_list.size).to eq 3
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

      context "with a complex scenario" do
        let(:scenario) { "complex-lvm-encrypt" }

        # Test to ensure it can handle encrypted disks and empty disks
        it "manages partition-less disks correctly" do
          expect(disks.filesystems).to be_a Y2Storage::DevicesLists::FilesystemsList
        end

        it "includes filesystems in encrypted devices but not filesystems within LVM" do
          expect(disks.filesystems.size).to eq 4
        end
      end
    end

    describe "#encryptions" do
      let(:scenario) { "complex-lvm-encrypt" }

      it "returns a filtered list of encryption devices" do
        expect(disks.encryptions).to be_a Y2Storage::DevicesLists::EncryptionsList
        enc_direct = disks.with(partition_table: nil).encryptions
        expect(enc_direct).to be_a Y2Storage::DevicesLists::EncryptionsList
        expect(enc_direct.size).to eq 2
      end

      it "includes encryptions in partitions but not encryptions in LVs" do
        expect(disks.encryptions.size).to eq 4
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

    describe "#with_name_or_partition" do
      it "returns a list of disks" do
        result = disks.with_name_or_partition("/dev/sda2")
        expect(result).to be_a(Y2Storage::DevicesLists::DisksList)
      end

      it "filters by a single disk name" do
        list = disks.with_name_or_partition("/dev/sda")
        expect(list.size).to eq 1
        expect(list.first.name).to eq "/dev/sda"
      end

      it "filters by a single partition name" do
        list = disks.with_name_or_partition("/dev/sda2")
        expect(list.size).to eq 1
        expect(list.first.name).to eq "/dev/sda"
      end

      it "filters by a set of names" do
        list = disks.with_name_or_partition(["/dev/sda1", "/dev/sda2", "/dev/sdb", "/dev/sdb1"])
        expect(list.size).to eq 2
        expect(list.map(&:name)).to contain_exactly("/dev/sda", "/dev/sdb")
      end

      it "returns an empty list if nothing matches" do
        list = disks.with_name_or_partition("non_existent")
        expect(list).to be_empty
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

      context "with LVM" do
        let(:scenario) { "complex-lvm-encrypt" }

        # Ensure that partitions used for encryption or LVM PVs are not a problem
        it "handles correctly partitions that are neither formatted or empty" do
          expect(partitions.filesystems).to be_a Y2Storage::DevicesLists::FilesystemsList
        end

        it "returns filesystems located in a partition or its encrypted device" do
          expect(partitions.filesystems.size).to eq 4
          expect(partitions.with(encryption: nil).filesystems.size).to eq 3
        end
      end
    end

    describe "#encryptions" do
      let(:scenario) { "complex-lvm-encrypt" }

      it "returns a filtered list of encryption devices" do
        expect(partitions.encryptions).to be_a Y2Storage::DevicesLists::EncryptionsList
        expect(partitions.encryptions.size).to eq 2
        parts_sda = partitions.with { |p| p.name.start_with? "/dev/sda" }
        expect(parts_sda.encryptions).to be_a Y2Storage::DevicesLists::EncryptionsList
        expect(parts_sda.encryptions.size).to eq 1
      end
    end

    describe "#disks" do
      it "returns a filtered list of disks" do
        parts_sda = partitions.with { |p| p.name.start_with? "/dev/sda" }
        expect(parts_sda.disks).to be_a Y2Storage::DevicesLists::DisksList
        expect(parts_sda.disks.size).to eq 1

        parts_none = partitions.with(name: "bad name")
        expect(parts_none.disks).to be_a Y2Storage::DevicesLists::DisksList
        expect(parts_none.disks.size).to eq 0

        expect(partitions.disks).to be_a Y2Storage::DevicesLists::DisksList
        expect(partitions.disks.size).to eq 2
      end
    end
  end

  describe Y2Storage::DevicesLists::FilesystemsList do
    let(:filesystems) { fake_devicegraph.filesystems }

    it "contains all filesystems by default" do
      expect(filesystems.size).to eq 7
      expect(full_list.size).to eq 7
    end

    describe "#with_mountpoint" do
      it "returns a list of filesystems" do
        result = filesystems.with_mountpoint("/home")
        expect(result).to be_a(Y2Storage::DevicesLists::FilesystemsList)
      end

      it "filters by a single mount point" do
        list = filesystems.with_mountpoint("/home")
        expect(list.size).to eq 1
        expect(list.first.type).to eq Storage::FsType_XFS
      end

      it "filters by a set of mount points" do
        list = filesystems.with_mountpoint(["/home", "/non_existent", "/"])
        expect(list.size).to eq 2
        types = list.map(&:type)
        expect(types).to contain_exactly(Storage::FsType_XFS, Storage::FsType_EXT4)
      end

      it "returns an empty list if nothing matches" do
        list = filesystems.with_mountpoint("non_existent")
        expect(list).to be_empty
      end
    end

    describe "#partitions" do
      it "returns a filtered list of partitions" do
        parts_ext4 = filesystems.with(type: Storage::FsType_EXT4).partitions
        parts_none = filesystems.with(label: "invented_label").partitions
        expect(parts_ext4).to be_a Y2Storage::DevicesLists::PartitionsList
        expect(parts_ext4.size).to eq 2
        expect(parts_none).to be_a Y2Storage::DevicesLists::PartitionsList
        expect(parts_none.size).to eq 0
      end

      context "with encrypted partitions" do
        let(:scenario) { "complex-lvm-encrypt" }

        it "returns both encrypted partitions and directly formatted ones" do
          expect(filesystems.partitions.size).to eq 4
        end
      end
    end

    describe "#disks" do
      it "returns a filtered list of disks" do
        disks_ext4 = filesystems.with(type: Storage::FsType_EXT4).disks
        disks_xfs = filesystems.with(type: Storage::FsType_XFS).disks
        expect(disks_ext4).to be_a Y2Storage::DevicesLists::DisksList
        expect(disks_ext4.size).to eq 2
        expect(disks_xfs).to be_a Y2Storage::DevicesLists::DisksList
        expect(disks_xfs.size).to eq 1
      end

      context "with encrypted partitions" do
        let(:scenario) { "complex-lvm-encrypt" }

        it "includes disks for encrypted partitions" do
          expect(filesystems.disks.size).to eq 2
        end
      end
    end

    describe "#lvm_lvs" do
      let(:scenario) { "lvm-two-vgs" }

      it "returns a filtered list of logical volumes" do
        lvs_ext4 = filesystems.with(type: Storage::FsType_EXT4).lvm_lvs
        lvs_none = filesystems.with(label: "invented_label").lvm_lvs
        expect(lvs_ext4).to be_a Y2Storage::DevicesLists::LvmLvsList
        expect(lvs_ext4.size).to eq 3
        expect(lvs_none).to be_a Y2Storage::DevicesLists::LvmLvsList
        expect(lvs_none.size).to eq 0
      end

      context "with encrypted logical volumes" do
        let(:scenario) { "complex-lvm-encrypt" }

        it "returns both encrypted volumes and directly formatted ones" do
          expect(filesystems.lvm_lvs.size).to eq 4
        end
      end
    end

    describe "#lvm_vgs" do
      let(:scenario) { "lvm-two-vgs" }

      it "returns a filtered list of volume groups" do
        vgs_ext4 = filesystems.with(type: Storage::FsType_EXT4).lvm_vgs
        vgs_xfs = filesystems.with(type: Storage::FsType_XFS).lvm_vgs
        expect(vgs_ext4).to be_a Y2Storage::DevicesLists::LvmVgsList
        expect(vgs_ext4.size).to eq 2
        expect(vgs_xfs).to be_a Y2Storage::DevicesLists::LvmVgsList
        expect(vgs_xfs.size).to eq 0
      end
    end

    describe "#encryptions" do
      let(:scenario) { "complex-lvm-encrypt" }

      it "returns a filtered list of encryption devices" do
        expect(filesystems.encryptions).to be_a Y2Storage::DevicesLists::EncryptionsList
        expect(filesystems.encryptions.size).to eq 2
      end

      it "includes directly formatted encryptions" do
        expect(filesystems.encryptions.map(&:name)).to contain_exactly(
          "/dev/mapper/cr_sda4", "/dev/mapper/cr_vg1_lv2"
        )
      end

      it "does not include encryptions in an underlying device (e.g. PV)" do
        expect(filesystems.encryptions.map(&:name)).not_to include(
          "/dev/mapper/cr_sdd", "/dev/mapper/cr_sde1"
        )
      end
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

    describe "#disks" do
      it "returns a filtered list of disks" do
        disks = spaces.disks
        expect(disks).to be_a Y2Storage::DevicesLists::DisksList
        expect(disks.size).to eq 3
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

    describe "#filesystems" do
      it "returns a filtered list of filesystems" do
        fs_vg0 = vgs.with(vg_name: "vg0").filesystems
        expect(fs_vg0).to be_a Y2Storage::DevicesLists::FilesystemsList
        expect(fs_vg0.size).to eq 2
        expect(vgs.filesystems).to be_a Y2Storage::DevicesLists::FilesystemsList
        expect(vgs.filesystems.size).to eq 3
        fs_none = vgs.with(vg_name: "wrong_name").filesystems
        expect(fs_none).to be_a Y2Storage::DevicesLists::FilesystemsList
        expect(fs_none.size).to eq 0
      end

      context "with encrypted logical volumes" do
        let(:scenario) { "complex-lvm-encrypt" }

        it "returns filesystem for both encrypted and plain logical volumes" do
          expect(vgs.filesystems.size).to eq 4
        end
      end
    end

    describe "#partitions" do
      it "returns a filtered list of partitions" do
        partitions_vg0 = vgs.with(vg_name: "vg0").partitions
        expect(partitions_vg0).to be_a Y2Storage::DevicesLists::PartitionsList
        expect(partitions_vg0.map(&:name)).to eq ["/dev/sda7"]
        expect(vgs.partitions).to be_a Y2Storage::DevicesLists::PartitionsList
        expect(vgs.partitions.size).to eq 3
        partitions_none = vgs.with(vg_name: "wrong_name").partitions
        expect(partitions_none).to be_a Y2Storage::DevicesLists::PartitionsList
        expect(partitions_none.size).to eq 0
      end

      context "with encrypted physical volumes" do
        let(:scenario) { "complex-lvm-encrypt" }

        it "returns partitions for both encrypted and plain physical volumes" do
          expect(vgs.partitions.size).to eq 2
        end
      end
    end

    describe "#disks" do
      it "returns a filtered list of disks" do
        disks_vg0 = vgs.with(vg_name: "vg0").disks
        expect(disks_vg0).to be_a Y2Storage::DevicesLists::DisksList
        expect(disks_vg0.map(&:name)).to eq ["/dev/sda"]
        expect(vgs.disks).to be_a Y2Storage::DevicesLists::DisksList
        expect(vgs.disks.map(&:name)).to eq ["/dev/sda"]
        disks_none = vgs.with(vg_name: "wrong_name").disks
        expect(disks_none).to be_a Y2Storage::DevicesLists::DisksList
        expect(disks_none.size).to eq 0
      end

      context "with encrypted physical volumes" do
        let(:scenario) { "complex-lvm-encrypt" }

        it "includes disks directly used as physical volumes, both encrypted and plain" do
          expect(vgs.disks.map(&:name)).to include("/dev/sdd", "/dev/sdg")
        end

        it "includes disks with partitions used as physical volumes, both encrypted and plain" do
          expect(vgs.disks.map(&:name)).to include "/dev/sde"
        end

        it "does not include disks not used for LVM" do
          expect(vgs.disks.size).to eq 3
        end
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

    describe "#lvm_vgs" do
      it "returns a filtered list of volume groups" do
        pvs_vg0 = pvs.with { |pv| pv.blk_device.name == "/dev/sda7" }
        expect(pvs.lvm_vgs).to be_a Y2Storage::DevicesLists::LvmVgsList
        expect(pvs.lvm_vgs.size).to eq 2
        expect(pvs_vg0.lvm_vgs).to be_a Y2Storage::DevicesLists::LvmVgsList
        expect(pvs_vg0.lvm_vgs.size).to eq 1
      end
    end

    describe "#partitions" do
      it "returns a filtered list of partitions" do
        pvs_vg0 = pvs.with { |pv| pv.lvm_vg.vg_name == "vg0" }
        expect(pvs_vg0.partitions).to be_a Y2Storage::DevicesLists::PartitionsList
        expect(pvs_vg0.partitions.map(&:name)).to eq ["/dev/sda7"]
        expect(pvs.partitions).to be_a Y2Storage::DevicesLists::PartitionsList
        expect(pvs.partitions.size).to eq 3
      end

      context "with encrypted physical volumes" do
        let(:scenario) { "complex-lvm-encrypt" }

        it "returns both encrypted partitions and directly used ones" do
          expect(pvs.partitions.size).to eq 2
        end
      end
    end

    describe "#disks" do
      it "returns a filtered list of disks" do
        pvs_vg0 = pvs.with { |pv| pv.lvm_vg.vg_name == "vg0" }
        expect(pvs_vg0.disks).to be_a Y2Storage::DevicesLists::DisksList
        expect(pvs_vg0.disks.map(&:name)).to eq ["/dev/sda"]
        expect(pvs.disks).to be_a Y2Storage::DevicesLists::DisksList
        expect(pvs_vg0.disks.map(&:name)).to eq ["/dev/sda"]
      end

      context "with encrypted physical volumes" do
        let(:scenario) { "complex-lvm-encrypt" }

        it "includes disks directly used as physical volumes, both encrypted and plain" do
          expect(pvs.disks.map(&:name)).to include("/dev/sdd", "/dev/sdg")
        end

        it "includes disks with partitions used as physical volumes, both encrypted and plain" do
          expect(pvs.disks.map(&:name)).to include "/dev/sde"
        end

        it "does not include disks not used for LVM" do
          expect(pvs.disks.size).to eq 3
        end
      end
    end
  end

  describe Y2Storage::DevicesLists::LvmLvsList do
    let(:scenario) { "lvm-two-vgs" }
    let(:lvs) { fake_devicegraph.lvs }

    it "contains all logical volumes by default" do
      expect(lvs.size).to eq 3
      expect(full_list.size).to eq 3
    end

    describe "#lvm_vgs" do
      it "returns a filtered list of volume groups" do
        vgs_lv1 = lvs.with(lv_name: "lv1").lvm_vgs
        vgs_lv2 = lvs.with(lv_name: "lv2").lvm_vgs
        expect(vgs_lv1).to be_a Y2Storage::DevicesLists::LvmVgsList
        expect(vgs_lv1.size).to eq 2
        expect(vgs_lv2).to be_a Y2Storage::DevicesLists::LvmVgsList
        expect(vgs_lv2.size).to eq 1
      end
    end

    describe "#filesystems" do
      it "returns a filtered list of filesystems" do
        lvs_lv1 = lvs.with(lv_name: "lv1")
        expect(lvs.filesystems).to be_a Y2Storage::DevicesLists::FilesystemsList
        expect(lvs.filesystems.size).to eq 3
        expect(lvs_lv1.filesystems).to be_a Y2Storage::DevicesLists::FilesystemsList
        expect(lvs_lv1.filesystems.size).to eq 2
      end

      context "with encrypted logical volumes" do
        let(:scenario) { "complex-lvm-encrypt" }

        it "can deal with encrypted logical volumes" do
          expect(lvs.filesystems).to be_a Y2Storage::DevicesLists::FilesystemsList
        end

        it "returns filesystems located in a logical volume or its encrypted device" do
          expect(lvs.filesystems.size).to eq 4
          expect(lvs.with(encryption: nil).filesystems.size).to eq 3
        end
      end
    end

    describe "#encryptions" do
      let(:scenario) { "complex-lvm-encrypt" }

      it "returns a filtered list of encryption devices" do
        expect(lvs.encryptions).to be_a Y2Storage::DevicesLists::EncryptionsList
        expect(lvs.encryptions.size).to eq 1
      end
    end
  end

  describe Y2Storage::DevicesLists::EncryptionsList do
    let(:scenario) { "complex-lvm-encrypt" }
    let(:encryptions) { fake_devicegraph.encryptions }

    it "contains all encrypted devices by default" do
      expect(encryptions.size).to eq(5)
      expect(full_list.size).to eq(5)
    end

    describe "#filesystems" do
      it "returns a list of filesystems" do
        expect(encryptions.filesystems).to be_a Y2Storage::DevicesLists::FilesystemsList
      end

      it "returns a filtered list of filesystems" do
        encs = encryptions.with { |e| e.name.include? "sda" }
        expect(encs.filesystems.size).to eq(1)

        encs = encryptions.with { |e| e.name.include? "bad name" }
        expect(encs.filesystems.size).to eq(0)
      end

      it "handles correctly encrypted devices without filesystem" do
        encs = encryptions.with { |e| e.name.include? "sdc" }
        expect(encs.filesystems.size).to eq(0)
      end

      it "returns all filesystems located in encrypted partitions or disks" do
        filesystems = encryptions.filesystems
        expect(filesystems.size).to eq 2
        expect(filesystems.map(&:type).uniq).to contain_exactly(ext4)
      end
    end

    describe "#disks" do
      it "returns a list of disks" do
        expect(encryptions.disks).to be_a Y2Storage::DevicesLists::DisksList
      end

      it "returns a filtered list of disks" do
        encs = encryptions.with { |e| e.name.include? "sda" }
        expect(encs.disks.size).to eq(1)

        encs = encryptions.with { |e| e.name.include? "bad name" }
        expect(encs.disks.size).to eq(0)
      end

      it "includes directly encrypted disks" do
        expect(encryptions.disks.map(&:name)).to(
          include("/dev/sdc", "/dev/sdd")
        )
      end

      it "includes disks with encrypted partitions" do
        expect(encryptions.disks.map(&:name)).to(
          include("/dev/sda", "/dev/sde")
        )
      end

      it "does not include a not encrypted disk under an encrypted lv" do
        expect(encryptions.disks.map(&:name)).not_to include("/dev/sdg")
      end

      it "does not include not encrypted disks" do
        disks = encryptions.disks
        expect(disks.map(&:name)).not_to(
          include("/dev/sdb", "/dev/sdf", "/dev/sdg")
        )
        expect(disks.size).to eq(4)
      end
    end

    describe "#partitions" do
      it "returns a list of partitions" do
        expect(encryptions.partitions).to be_a(Y2Storage::DevicesLists::PartitionsList)
        expect(encryptions.partitions.size).to eq(2)
      end

      it "return a filtered list of partitions" do
        encs = encryptions.with { |e| e.name.include? "sda" }
        expect(encs.partitions.size).to eq(1)

        encs = encryptions.with { |e| e.name.include? "bad name" }
        expect(encs.partitions.size).to eq(0)
      end

      it "handles correctly encrypted devices without partitions" do
        encs = encryptions.with(name: "/dev/mapper/cr_sdc")
        expect(encs.partitions.size).to eq(0)
      end

      it "does not return partitions for an encrypted lv" do
        encs = encryptions.with { |e| e.name.end_with? "cr_vg1_lv2" }
        expect(encs.partitions.size).to eq(0)
      end

      # TODO: test with encrypted PV
    end

    describe "#lvm_lvs" do
      it "returns a list of lvs" do
        expect(encryptions.lvm_lvs).to be_a(Y2Storage::DevicesLists::LvmLvsList)
      end

      it "returns only encrypted lvs" do
        lvs = encryptions.lvm_lvs
        expect(lvs.size).to eq(1)
        expect(lvs.map(&:lv_name)).to contain_exactly("lv2")
        expect(lvs.vgs.map(&:vg_name)).to contain_exactly("vg1")
      end
    end
  end
end
