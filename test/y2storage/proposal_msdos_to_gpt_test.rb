#!/usr/bin/env rspec
# Copyright (c) [2024] SUSE LLC
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
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  using Y2Storage::Refinements::SizeCasts

  describe "#propose" do
    include_context "proposal"

    subject(:proposal) { described_class.new(settings: settings) }
    let(:architecture) { :x86 }
    let(:efi) { false }

    before do
      # Speed-up things by avoiding calls to hwinfo
      allow_any_instance_of(Y2Storage::Disk).to receive(:hwinfo).and_return(Y2Storage::HWInfoDisk.new)
    end

    context "when all partitions from an MSDOS partition table end up being deleted" do
      let(:scenario) { "windows-pc" }

      # As straightforward as possible to simplify calculations
      let(:control_file_content) { { "partitioning" => { "volumes" => volumes_spec } } }
      let(:volumes_spec) do
        [{ "mount_point" => "/", "fs_type" => "ext4", "desired_size" => "795 GiB" }]
      end

      before do
        settings.other_delete_mode = :ondemand
        settings.windows_delete_mode = :ondemand
      end

      it "creates a new GPT partition table" do
        proposal.propose
        disk = proposal.devices.disks.first
        expect(disk.partition_table.type.is?(:gpt)).to eq true
      end

      it "correctly creates the boot partitions for the new GPT table" do
        proposal.propose
        disk = proposal.devices.disks.first
        expect(disk.partitions.map(&:id)).to include Y2Storage::PartitionId::BIOS_BOOT
      end
    end
  end
end
