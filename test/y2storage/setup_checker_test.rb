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

describe Y2Storage::SetupChecker do
  using Y2Storage::Refinements::SizeCasts

  before do
    fake_scenario(scenario)
  end

  let(:scenario) { "empty_hard_disk_gpt_50GiB" }

  let(:disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }

  def create_root
    root = disk.partition_table.create_partition("/dev/sda2",
      Y2Storage::Region.create(1050624, 33554432, 512),
      Y2Storage::PartitionType::PRIMARY)
    root.size = 15.GiB
    fs = root.create_filesystem(Y2Storage::Filesystems::Type::EXT4)
    fs.mount_point = "/"
  end

  subject { described_class.new(fake_devicegraph) }

  before do
    allow(Y2Storage::BootRequirementsChecker).to receive(:new).and_return(boot_checker)
    allow(boot_checker).to receive(:errors).and_return(boot_errors)

    allow(Y2Storage::ProposalSettings).to receive(:new_for_current_product).and_return(settings)
    allow(settings).to receive(:volumes).and_return(product_volumes)
  end

  let(:boot_checker) { instance_double(Y2Storage::BootRequirementsChecker) }

  let(:settings) { instance_double(Y2Storage::ProposalSettings) }

  let(:boot_errors) { [] }

  let(:product_volumes) { [] }

  let(:boot_error) { instance_double(Y2Storage::SetupError) }

  let(:root_volume) do
    volume = Y2Storage::VolumeSpecification.new({})
    volume.mount_point = "/"
    volume.min_size = 10.GiB
    volume.fs_types = Y2Storage::Filesystems::Type.root_filesystems
    volume.proposed = true
    volume.proposed_configurable = false
    volume
  end

  let(:swap_volume) do
    volume = Y2Storage::VolumeSpecification.new({})
    volume.mount_point = "swap"
    volume.min_size = 4.GiB
    volume.partition_id = Y2Storage::PartitionId::SWAP
    volume.fs_types = [Y2Storage::Filesystems::Type::SWAP]
    volume.proposed = true
    volume.proposed_configurable = false
    volume
  end

  let(:home_volume) do
    volume = Y2Storage::VolumeSpecification.new({})
    volume.mount_point = "/home"
    volume.min_size = 10.GiB
    volume.partition_id = Y2Storage::PartitionId::LINUX
    volume.fs_types = Y2Storage::Filesystems::Type.home_filesystems
    volume.proposed = true
    volume.proposed_configurable = true
    volume
  end

  describe "#valid?" do
    context "when some mandatory product volume is not present in the system" do
      let(:product_volumes) { [root_volume, home_volume] }
      let(:boot_errors) { [] }

      it "returns false" do
        expect(subject.valid?).to eq(false)
      end
    end

    context "when there is some boot error" do
      let(:product_volumes) { [] }
      let(:boot_errors) { [boot_error] }

      it "returns false" do
        expect(subject.valid?).to eq(false)
      end
    end

    context "when all mandatory product volumes are present in the system and there is no boot error" do
      let(:product_volumes) { [root_volume, home_volume] }
      let(:boot_errors) { [] }

      before do
        create_root
      end

      it "returns true" do
        expect(subject.valid?).to eq(true)
      end
    end
  end

  describe "#bootable?" do
    context "when there is some boot error" do
      let(:boot_errors) { [boot_error] }

      it "returns false" do
        expect(subject.bootable?).to eq(false)
      end
    end

    context "when there is no boot error" do
      let(:boot_errors) { [] }

      it "returns true" do
        expect(subject.bootable?).to eq(true)
      end
    end
  end

  describe "#errors" do
    let(:boot_error1) { instance_double(Y2Storage::SetupError) }
    let(:boot_error2) { instance_double(Y2Storage::SetupError) }
    let(:boot_errors) { [boot_error1, boot_error2] }

    let(:product_volumes) { [root_volume, swap_volume, home_volume] }

    it "includes all boot errors" do
      expect(subject.errors).to include(boot_error1, boot_error2)
    end

    it "does not include an error for optional product volumes" do
      expect(subject.errors).to_not include(an_object_having_attributes(missing_volume: home_volume))
    end

    it "includes an error for each mandatory product volume not present in the system" do
      expect(subject.errors).to include(an_object_having_attributes(missing_volume: root_volume))
      expect(subject.errors).to include(an_object_having_attributes(missing_volume: swap_volume))
    end

    context "when a mandatory product volume is present in the system" do
      before do
        create_root
      end

      it "does not include an error for that volume" do
        expect(subject.errors).to_not include(an_object_having_attributes(missing_volume: root_volume))
      end
    end

    context "when there is no boot error and all mandatory product volumes are present in the system" do
      let(:boot_errors) { [] }
      let(:product_volumes) { [root_volume, home_volume] }

      before do
        create_root
      end

      it "returns an empty list" do
        expect(subject.errors).to be_empty
      end
    end
  end

  describe "#boot_errors" do
    let(:boot_error1) { instance_double(Y2Storage::SetupError) }
    let(:boot_error2) { instance_double(Y2Storage::SetupError) }
    let(:boot_errors) { [boot_error1, boot_error2] }

    let(:product_volumes) { [root_volume, swap_volume, home_volume] }

    it "includes all boot errors" do
      expect(subject.boot_errors).to contain_exactly(boot_error1, boot_error2)
    end

    context "when there is no boot error" do
      let(:boot_errors) { [] }

      it "returns an empty list" do
        expect(subject.boot_errors).to be_empty
      end
    end
  end

  describe "#product_errors" do
    let(:boot_error1) { instance_double(Y2Storage::SetupError) }
    let(:boot_error2) { instance_double(Y2Storage::SetupError) }
    let(:boot_errors) { [boot_error1, boot_error2] }

    let(:product_volumes) { [root_volume, swap_volume, home_volume] }

    it "returns a list of setup errors" do
      expect(subject.product_errors).to all(be_a(Y2Storage::SetupError))
    end

    it "does not include boot errors" do
      expect(subject.product_errors).to_not include(boot_error1, boot_error2)
    end

    it "does not include an error for optional product volumes" do
      expect(subject.product_errors)
        .to_not include(an_object_having_attributes(missing_volume: home_volume))
    end

    it "includes an error for each mandatory product volume not present in the system" do
      expect(subject.product_errors).to include(an_object_having_attributes(missing_volume: root_volume))
      expect(subject.product_errors).to include(an_object_having_attributes(missing_volume: swap_volume))
    end

    context "when a mandatory product volume is present in the system" do
      before do
        create_root
      end

      it "does not include an error for that volume" do
        expect(subject.product_errors)
          .to_not include(an_object_having_attributes(missing_volume: root_volume))
      end
    end

    context "when all mandatory product volumes are present in the system" do
      let(:product_volumes) { [root_volume, home_volume] }

      before do
        create_root
      end

      it "returns an empty list" do
        expect(subject.product_errors).to be_empty
      end
    end
  end
end
