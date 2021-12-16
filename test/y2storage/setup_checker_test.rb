#!/usr/bin/env rspec
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
    fs.mount_path = "/"
  end

  subject { described_class.new(fake_devicegraph) }

  before do
    allow(Y2Storage::BootRequirementsChecker).to receive(:new).and_return(boot_checker)
    allow(boot_checker).to receive(:warnings).and_return(boot_warnings)
    allow(boot_checker).to receive(:errors).and_return(fatal_errors)

    allow(Y2Storage::ProposalSettings).to receive(:new_for_current_product).and_return(settings)
    allow(settings).to receive(:volumes).and_return(product_volumes)

    # We have to use allow_any_instance due to the nature of libstorage-ng bindings (they return
    # a different object for each query to the devicegraph)
    allow_any_instance_of(Y2Storage::Filesystems::BlkFilesystem).to receive(:missing_mount_options)
      .and_return(missing_root_opts)
  end

  let(:boot_checker) { instance_double(Y2Storage::BootRequirementsChecker) }

  let(:settings) { instance_double(Y2Storage::ProposalSettings) }

  let(:boot_warnings) { [] }

  let(:fatal_errors) { [] }

  let(:product_volumes) { [] }

  let(:missing_root_opts) { [] }

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
      let(:boot_warnings) { [] }

      it "returns false" do
        expect(subject.valid?).to eq(false)
      end
    end

    context "when there is some boot error" do
      let(:product_volumes) { [] }
      let(:boot_warnings) { [boot_error] }

      it "returns false" do
        expect(subject.valid?).to eq(false)
      end
    end

    context "when there is some error in the mount options" do
      before { create_root }

      let(:product_volumes) { [] }
      let(:boot_warnings) { [] }
      let(:missing_root_opts) { ["_netdev"] }

      it "returns false" do
        expect(subject.valid?).to eq(false)
      end
    end

    context "when there is a fatal error" do
      let(:fatal_errors) { [boot_error] }

      it "returns false" do
        expect(subject.valid?).to eq(false)
      end
    end

    context "when all mandatory product volumes are present in the system and there is no boot error" do
      let(:product_volumes) { [root_volume, home_volume] }
      let(:boot_warnings) { [] }
      let(:missing_root_opts) { [] }

      before do
        create_root
      end

      it "returns true" do
        expect(subject.valid?).to eq(true)
      end
    end
  end

  describe "#warnings" do
    let(:boot_error1) { instance_double(Y2Storage::SetupError) }
    let(:boot_error2) { instance_double(Y2Storage::SetupError) }
    let(:boot_warnings) { [boot_error1, boot_error2] }

    let(:product_volumes) { [root_volume, swap_volume, home_volume] }

    it "includes all boot warnings" do
      expect(subject.warnings).to include(boot_error1, boot_error2)
    end

    it "does not include an error for optional product volumes" do
      expect(subject.warnings).to_not include(an_object_having_attributes(missing_volume: home_volume))
    end

    it "includes an error for each mandatory product volume not present in the system" do
      expect(subject.warnings).to include(an_object_having_attributes(missing_volume: root_volume))
      expect(subject.warnings).to include(an_object_having_attributes(missing_volume: swap_volume))
    end

    context "when a mandatory product volume is present in the system" do
      before do
        create_root
      end

      it "does not include an error for that volume" do
        expect(subject.warnings).to_not include(an_object_having_attributes(missing_volume: root_volume))
      end
    end

    context "when there is no boot error, mount options are ok and all mandatory volumes are present" do
      let(:boot_warnings) { [] }
      let(:product_volumes) { [root_volume, home_volume] }

      before do
        create_root
      end

      it "returns an empty list" do
        expect(subject.warnings).to be_empty
      end
    end

    context "when a mount option is missing for some mount point" do
      before { create_root }
      let(:boot_warnings) { [] }
      let(:missing_root_opts) { ["_netdev"] }

      it "includes an error mentioning the missing option" do
        expect(subject.warnings.map(&:message)).to include(an_object_matching(/_netdev/))
      end
    end
  end

  describe "#boot_warnings" do
    let(:boot_error1) { instance_double(Y2Storage::SetupError) }
    let(:boot_error2) { instance_double(Y2Storage::SetupError) }
    let(:boot_warnings) { [boot_error1, boot_error2] }

    let(:product_volumes) { [root_volume, swap_volume, home_volume] }

    it "includes all boot errors" do
      expect(subject.boot_warnings).to contain_exactly(boot_error1, boot_error2)
    end

    context "when there is no boot error" do
      let(:boot_warnings) { [] }

      it "returns an empty list" do
        expect(subject.boot_warnings).to be_empty
      end
    end
  end

  describe "#product_warnings" do
    let(:boot_error1) { instance_double(Y2Storage::SetupError) }
    let(:boot_error2) { instance_double(Y2Storage::SetupError) }
    let(:boot_warnings) { [boot_error1, boot_error2] }

    let(:product_volumes) { [root_volume, swap_volume, home_volume] }

    it "returns a list of setup errors" do
      expect(subject.product_warnings).to all(be_a(Y2Storage::SetupError))
    end

    it "does not include boot errors" do
      expect(subject.product_warnings).to_not include(boot_error1, boot_error2)
    end

    it "does not include an error for optional product volumes" do
      expect(subject.product_warnings)
        .to_not include(an_object_having_attributes(missing_volume: home_volume))
    end

    it "includes an error for each mandatory product volume not present in the system" do
      expect(subject.product_warnings).to include(
        an_object_having_attributes(missing_volume: root_volume)
      )
      expect(subject.product_warnings).to include(
        an_object_having_attributes(missing_volume: swap_volume)
      )
    end

    context "when a mandatory product volume is present in the system" do
      before do
        create_root
      end

      it "does not include an error for that volume" do
        expect(subject.product_warnings)
          .to_not include(an_object_having_attributes(missing_volume: root_volume))
      end
    end

    context "when a mandatory product volume is mounted as NFS" do
      before do
        fs = Y2Storage::Filesystems::Nfs.create(fake_devicegraph, "server", "/path")
        fs.mount_path = "/"
      end

      it "does not include an error for that volume" do
        expect(subject.product_warnings)
          .to_not include(an_object_having_attributes(missing_volume: root_volume))
      end
    end

    context "when all mandatory product volumes are present in the system" do
      let(:product_volumes) { [root_volume, home_volume] }

      before do
        create_root
      end

      it "returns an empty list" do
        expect(subject.product_warnings).to be_empty
      end
    end

    # Regression test
    context "when old settings format is used" do
      let(:product_volumes) { nil }

      it "returns an empty list" do
        expect(subject.product_warnings).to be_empty
      end
    end
  end

  describe "#mount_warnings" do
    before { create_root }

    let(:boot_error1) { instance_double(Y2Storage::SetupError) }
    let(:boot_error2) { instance_double(Y2Storage::SetupError) }
    let(:boot_warnings) { [boot_error1, boot_error2] }

    context "if there are no missing mount options" do
      let(:missing_root_opts) { [] }

      it "returns an empty list" do
        expect(subject.mount_warnings).to be_empty
      end
    end

    context "if there is a missing mount option for a given mount point" do
      let(:missing_root_opts) { ["extra_option"] }

      it "returns a list of setup errors" do
        expect(subject.product_warnings).to all(be_a(Y2Storage::SetupError))
      end

      it "does not include boot errors" do
        expect(subject.product_warnings).to_not include(boot_error1, boot_error2)
      end

      it "includes an error for the affected mount point and missing option" do
        warning = subject.mount_warnings.first
        expect(warning.message).to include "/"
        expect(warning.message).to include "extra_option"
      end
    end

    context "if there are several missing mount options for the same mount point" do
      let(:missing_root_opts) { ["one", "two"] }

      it "returns a list of setup errors" do
        expect(subject.product_warnings).to all(be_a(Y2Storage::SetupError))
      end

      it "does not include boot errors" do
        expect(subject.product_warnings).to_not include(boot_error1, boot_error2)
      end

      it "includes an error for the affected mount point with all the missing options" do
        warning = subject.mount_warnings.first
        expect(warning.message).to include "/"
        expect(warning.message).to include "one,two"
      end
    end
  end
end
