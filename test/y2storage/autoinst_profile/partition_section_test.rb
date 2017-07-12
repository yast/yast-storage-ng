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

require_relative "../spec_helper"
require "y2storage"

describe Y2Storage::AutoinstProfile::PartitionSection do
  before { fake_scenario("autoyast_drive_examples") }

  def device(name)
    Y2Storage::BlkDevice.find_by_name(fake_devicegraph, "/dev/#{name}")
  end

  describe ".new_from_storage" do
    def section_for(name)
      described_class.new_from_storage(device(name))
    end

    it "returns a PartitionSection object" do
      expect(section_for("dasdb1")).to be_a Y2Storage::AutoinstProfile::PartitionSection
    end

    it "correctly initializes #partition_nr" do
      expect(section_for("dasdb1").partition_nr).to eq 1
      expect(section_for("sdc3").partition_nr).to eq 3
    end

    it "initializes #partition_type to 'primary' for primary partitions" do
      expect(section_for("sdd3").partition_type).to eq "primary"
    end

    it "initializes #partition_type to nil for logical partitions" do
      expect(section_for("sdd4").partition_type).to be_nil
    end

    it "initializes #size to the exact device size in bytes" do
      expect(section_for("sdb1").size).to eq Y2Storage::DiskSize.GiB(780).to_i.to_s
    end

    context "if the partition contains a filesystem" do
      it "initializes #filesystem with the corresponding symbol" do
        expect(section_for("dasdb1").filesystem).to eq :swap
        expect(section_for("dasdb2").filesystem).to eq :btrfs
        expect(section_for("dasdb3").filesystem).to eq :xfs
      end

      it "initializes #label to the filesystem label" do
        expect(section_for("dasdb2").label).to eq "suse_root"
      end

      it "initializes #label to nil if the filesystem has no label" do
        expect(section_for("dasdb3").label).to be_nil
      end

      context "if the filesystem contains mounting information" do
        it "initializes #mount and #mountby" do
          section = section_for("sdc3")
          expect(section.mount).to eq "/"
          expect(section.mountby).to eq :uuid
        end
      end

      context "if the filesystem is not configured to be mounted" do
        it "initializes #mount and #mountby to nil" do
          section = section_for("dasdb2")
          expect(section.mount).to be_nil
          expect(section.mountby).to be_nil
        end
      end

      it "initializes #format to true for most partition ids" do
        expect(section_for("sdg1").format).to eq true
        expect(section_for("sdg4").format).to eq true
      end

      # Weird logic inherited from the old code
      it "initializes #format to false for PReP and DOS16 partitions" do
        expect(section_for("sdg2").format).to eq false
        expect(section_for("sdg3").format).to eq false
      end
    end

    context "if the partition contains no filesystem" do
      before { allow_any_instance_of(Y2Storage::Partition).to receive(:filesystem).and_return nil }

      it "initializes #filesystem, #label, #mount and #mountby to nil" do
        expect(section_for("sdc3").filesystem).to be_nil
        expect(section_for("sdc3").label).to be_nil
        expect(section_for("sdc3").mount).to be_nil
        expect(section_for("sdc3").mountby).to be_nil
      end

      it "initializes #format to false despite the partition id" do
        expect(section_for("sdg1").format).to eq false
        expect(section_for("sdg2").format).to eq false
        expect(section_for("sdg3").format).to eq false
        expect(section_for("sdg4").format).to eq false
      end
    end

    context "if the partition is encrypted" do
      it "initializes #crypt_key to a generic string" do
        expect(section_for("sdf7").crypt_key).to eq "ENTER KEY HERE"
      end

      it "initializes #loop_fs and #crypt_key to true" do
        section = section_for("sdf7")
        expect(section.crypt_fs).to eq true
        expect(section.loop_fs).to eq true
      end
    end

    context "if the partition is not encrypted" do
      # Legacy behavior, use the same string we have always used
      it "initializes #crypt_key to a generic string" do
        expect(section_for("sdf7").crypt_key).to eq "ENTER KEY HERE"
      end

      it "initializes #crypt_key, #loop_fs and #crypt_key to nil" do
        section = section_for("sdf6")
        expect(section.crypt_fs).to be_nil
        expect(section.crypt_fs).to be_nil
        expect(section.loop_fs).to be_nil
      end
    end

    context "if the partition has a typical Windows id" do
      let(:dev) { device("sdb1") }
      let(:mountpoint) { nil }

      before do
        # SWIG makes very hard to use proper mocking here with
        # allow(dev.filesystem).to(receive(:y)) because you can get different
        # Ruby wrapper objects for the same C++ filesystem. So let's simply
        # assign the values instead of intercepting the query calls.
        dev.filesystem.mountpoint = mountpoint if mountpoint
      end

      # Weird legacy behavior
      context "and it's configured to be mounted under /boot" do
        let(:mountpoint) { "/boot" }

        it "initializes #partition_id to 259 (legacy id for BIOS BOOT)" do
          section = described_class.new_from_storage(dev)
          expect(section.partition_id).to eq 259
        end
      end

      context "and it's not configured to be mounted under /boot" do
        let(:mountpoint) { nil }

        it "initializes #partition_id with the corresponding legacy number" do
          section = described_class.new_from_storage(dev)
          expect(section.partition_id).to eq 7
        end
      end
    end

    context "if the partition has a non-Windows id " do
      it "initializes #partition_id with the corresponding legacy number" do
        # Legacy (and also current) value for Linux
        expect(section_for("sdh1").partition_id).to eq 131
        # Legacy value for bios_boot (current is 257)
        expect(section_for("sdh2").partition_id).to eq 259
      end
    end
  end

  describe ".new_from_hashes" do
    let(:hash) { { "filesystem" => :ntfs, "label" => "", "partition_id" => 7 } }

    it "returns a PartitionSection object" do
      expect(described_class.new_from_hashes(hash)).to be_a Y2Storage::AutoinstProfile::PartitionSection
    end

    it "initializes scalars like #filesystem or #partition_id to their values in the array" do
      section = described_class.new_from_hashes(hash)
      expect(section.filesystem).to eq :ntfs
      expect(section.partition_id).to eq 7
    end

    it "initializes scalars not present in the hash to nil" do
      section = described_class.new_from_hashes(hash)
      expect(section.create).to be_nil
    end

    it "initializes empty scalars to nil" do
      section = described_class.new_from_hashes(hash)
      expect(section.label).to be_nil
    end

    it "initializes #subvolumes to an empty array if not present in the hash" do
      section = described_class.new_from_hashes(hash)
      expect(section.subvolumes).to eq []
    end

    context "when raid_options are not present" do
      it "initializes raid_options to nil" do
        section = described_class.new_from_hashes(hash)
        expect(section.raid_options).to be_nil
      end
    end

    context "when raid_options are present" do
      let(:hash) { { "raid_options" => { "chunk_size" => "1M" } } }

      it "initalizes raid_options" do
        section = described_class.new_from_hashes(hash)
        expect(section.raid_options).to be_a(Y2Storage::AutoinstProfile::RaidOptionsSection)
        expect(section.raid_options.chunk_size).to eq("1M")
      end
    end
  end

  describe "#to_hashes" do
    subject(:section) { described_class.new }

    it "returns a hash with all the non-blank values using strings as keys" do
      section.filesystem = :btrfs
      section.create = true
      expect(section.to_hashes).to eq("filesystem" => :btrfs, "create" => true)
    end

    it "returns an empty hash if all the values are blank" do
      expect(section.to_hashes).to eq({})
    end

    it "does not export #subvolumes if it is empty" do
      section.subvolumes = []
      expect(section.to_hashes.keys).to_not include "subvolumes"
    end
  end

  describe "#type_for_filesystem" do
    subject(:section) { described_class.new }

    it "returns nil if #filesystem is not set" do
      section.filesystem = nil
      expect(subject.type_for_filesystem).to be_nil
    end

    it "returns a Filesystems::Type corresponding to the symbol at #filesystem" do
      section.filesystem = :swap
      expect(subject.type_for_filesystem).to eq Y2Storage::Filesystems::Type::SWAP
      section.filesystem = :btrfs
      expect(subject.type_for_filesystem).to eq Y2Storage::Filesystems::Type::BTRFS
    end

    it "returns nil for unknown values of #filesystem" do
      section.filesystem = :strange
      expect(subject.type_for_filesystem).to be_nil
    end
  end

  describe "#id_for_partition" do
    subject(:section) { described_class.new }

    before { section.partition_id = partition_id }

    context "if #partition_id is set" do
      context "to a legacy integer value" do
        let(:partition_id) { 259 }

        it "returns the corresponding PartitionId object" do
          expect(section.id_for_partition).to eq Y2Storage::PartitionId::BIOS_BOOT
        end
      end

      context "to a standard integer value" do
        let(:partition_id) { 7 }

        it "returns the corresponding PartitionId object" do
          expect(section.id_for_partition).to eq Y2Storage::PartitionId::NTFS
        end
      end
    end

    context "if #partition_id is not set" do
      let(:partition_id) { nil }

      it "returns PartitionId:SWAP if #filesystem is :swap" do
        section.filesystem = :swap
        expect(section.id_for_partition).to eq Y2Storage::PartitionId::SWAP
      end

      it "returns PartitionId::LINUX for any other #filesystem value" do
        section.filesystem = :btrfs
        expect(section.id_for_partition).to eq Y2Storage::PartitionId::LINUX
        section.filesystem = :ntfs
        expect(section.id_for_partition).to eq Y2Storage::PartitionId::LINUX
        section.filesystem = nil
        expect(section.id_for_partition).to eq Y2Storage::PartitionId::LINUX
      end
    end
  end
end
