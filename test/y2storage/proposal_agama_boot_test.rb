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

describe Y2Storage::MinGuidedProposal do
  describe "#propose with settings in the Agama style" do
    subject(:proposal) { described_class.new(settings: settings) }

    include_context "proposal"
    let(:scenario) { "empty_hard_disk_gpt_50GiB" }
    let(:architecture) { :x86 }
    let(:settings_format) { :ng }
    let(:control_file_content) { { "partitioning" => { "volumes" => volumes } } }
    let(:volumes) { [{ "mount_point" => "/", "fs_type" => "xfs", "min_size" => "10 GiB" }] }

    before do
      # Speed-up things by avoiding calls to hwinfo
      allow_any_instance_of(Y2Storage::Disk).to receive(:hwinfo).and_return(Y2Storage::HWInfoDisk.new)

      settings.candidate_devices = ["/dev/sda"]
      settings.root_device = "/dev/sda"

      allow(storage_arch).to receive(:efiboot?).and_return(efi)
    end

    context "in an EFI system" do
      let(:efi) { true }

      it "creates an ESP partition" do
        proposal.propose
        mount_points = proposal.devices.mount_points.map(&:path)
        expect(proposal.devices.partitions.size).to eq 2
        expect(mount_points).to contain_exactly("/boot/efi", "/")
      end

      context "if ProposalSettings#boot is set to false" do
        before { settings.boot = false }

        it "does not create any extra partition for booting" do
          proposal.propose
          mount_points = proposal.devices.mount_points.map(&:path)
          expect(proposal.devices.partitions.size).to eq 1
          expect(mount_points).to contain_exactly("/")
        end
      end
    end

    context "in an legacy x86 system" do
      let(:efi) { false }

      it "creates a bios boot partition" do
        proposal.propose
        partitions = proposal.devices.partitions
        expect(partitions.size).to eq 2
        expect(partitions.map(&:id)).to contain_exactly(
          Y2Storage::PartitionId::BIOS_BOOT, Y2Storage::PartitionId::LINUX
        )
      end

      context "if ProposalSettings#boot is set to false" do
        before { settings.boot = false }

        it "does not create any extra partition for booting" do
          proposal.propose
          partitions = proposal.devices.partitions
          expect(partitions.size).to eq 1
          expect(partitions.first.id.to_sym).to eq :linux
        end
      end
    end
  end
end
