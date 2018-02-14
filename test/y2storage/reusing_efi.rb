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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::BootRequirementsChecker do
  using Y2Storage::Refinements::SizeCasts

  before do
    Y2Storage::StorageManager.create_test_instance
    Y2Storage::StorageManager.instance.probe_from_yaml(input_file_for("empty_hard_disk_gpt_50GiB"))

    allow(Y2Storage::StorageManager.instance).to receive(:arch).and_return(storage_arch)

    allow(storage_arch).to receive(:x86?).and_return(architecture == :x86)
    allow(storage_arch).to receive(:ppc?).and_return(architecture == :ppc)
    allow(storage_arch).to receive(:s390?).and_return(architecture == :s390)
    allow(storage_arch).to receive(:efiboot?).and_return(efiboot)
  end

  let(:storage_arch) { instance_double("::Storage::Arch") }

  let(:architecture) { :x86 }

  let(:efiboot) { true }

  let(:devicegraph) { Y2Storage::StorageManager.instance.staging }

  let(:disk) { devicegraph.disks.first }

  let(:partition) { disk.partitions.first }

  subject(:checker) { described_class.new(devicegraph) }

  def create_partition(disk)
    slot = disk.partition_table.unused_partition_slots.first
    disk.partition_table.create_partition(slot.name, slot.region, Y2Storage::PartitionType::PRIMARY)
  end

  RSpec.shared_examples "not_reuse_efi" do
    it "does not reuse the partition" do
      expect(checker.needed_partitions).to contain_exactly(
        an_object_having_attributes(mount_point: "/boot/efi", reuse: nil)
      )
    end
  end

  RSpec.shared_examples "reuse_efi" do
    it "reuses the existing EFI partition" do
      expect(checker.needed_partitions).to contain_exactly(
        an_object_having_attributes(mount_point: "/boot/efi", reuse: "/dev/sda1")
      )
    end
  end

  RSpec.shared_examples "not_reuse_partition_id" do
    context "and the id is ESP" do
      let(:partition_id) { Y2Storage::PartitionId::ESP }

      include_examples "not_reuse_efi"
    end

    context "and the id is no ESP" do
      let(:partition_id) { Y2Storage::PartitionId::LINUX }

      include_examples "not_reuse_efi"
    end
  end

  RSpec.shared_examples "not_reuse" do
    context "and it is smaller than the proposal min" do
      let(:size) { 32.MiB }

      include_examples "not_reuse_partition_id"
    end

    context "and it is bigger than the proposal max" do
      let(:size) { 501.MiB }

      include_examples "not_reuse_partition_id"
    end

    context "and it has a proper size" do
      let(:size) { 33.MiB }

      include_examples "not_reuse_partition_id"
    end
  end

  context "if there is a partition without filesystem" do
    before do
      create_partition(disk)
      partition.id = partition_id
      partition.size = size
    end

    include_examples "not_reuse"
  end

  context "if there is a partition with a non VFAT filesystem" do
    before do
      create_partition(disk)
      partition.create_filesystem(Y2Storage::Filesystems::Type::EXT3)
      partition.id = partition_id
      partition.size = size
    end

    include_examples "not_reuse"
  end

  context "if there is a partition formatted as VFAT" do
    before do
      create_partition(disk)
      partition.create_filesystem(Y2Storage::Filesystems::Type::VFAT)
      partition.id = partition_id
      partition.size = size
    end

    context "and it is smaller than the proposal min" do
      let(:size) { 32.MiB }

      include_examples "not_reuse_partition_id"
    end

    context "and it is bigger than the proposal max" do
      let(:size) { 501.MiB }

      context "and the id is ESP (FIXME: should we check content?)" do
        let(:partition_id) { Y2Storage::PartitionId::ESP }

        include_examples "reuse_efi"
      end

      context "and the id is no ESP (FIXME: should we check content?)" do
        let(:partition_id) { Y2Storage::PartitionId::LINUX }

        include_examples "not_reuse_efi"
      end
    end

    context "and it has a proper size" do
      let(:size) { 33.MiB }

      context "and the id is ESP (FIXME: should we check content?)" do
        let(:partition_id) { Y2Storage::PartitionId::ESP }

        include_examples "reuse_efi"
      end

      context "and the id is no ESP (FIXME: should we check content?)" do
        let(:partition_id) { Y2Storage::PartitionId::LINUX }

        include_examples "not_reuse_efi"
      end
    end
  end
end
