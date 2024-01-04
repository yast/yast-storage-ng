#!/usr/bin/env rspec
# Copyright (c) [2023] SUSE LLC
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
  describe "#propose in a system with pre-existing swap partitions" do
    subject(:proposal) { described_class.new(settings:) }

    include_context "proposal"
    let(:architecture) { :x86 }
    let(:settings_format) { :ng }
    let(:control_file_content) do
      { "partitioning" => { "volumes" => volumes } }
    end

    let(:scenario) { "autoyast_drive_examples" }

    let(:volumes) { [root_vol, swap_vol] }
    let(:root_vol) do
      { "mount_point" => "/", "fs_type" => "xfs", "min_size" => "5 GiB", "max_size" => "30 GiB" }
    end
    let(:swap_vol) do
      { "mount_point" => "swap", "fs_type" => "swap", "min_size" => "500 MiB", "max_size" => "2 GiB" }
    end

    RSpec.shared_examples "reuse best swap" do
      it "reuses the pre-existing swap with more suitable size" do
        proposal.propose
        dasdb1 = proposal.devices.find_by_name("/dev/dasdb1")
        expect(dasdb1.exists_in_probed?).to eq true
        expect(dasdb1).to have_attributes(
          # This proves is mounted as swap
          filesystem_mountpoint: "swap",
          # This proves is not re-formatted
          filesystem_label:      "swap_dasdb",
          size:                  Y2Storage::DiskSize.GiB(1)
        )
      end
    end

    RSpec.shared_examples "new swap" do
      it "creates a new swap partition" do
        proposal.propose
        swap = proposal.devices.partitions.find { |p| p.filesystem&.mount_path == "swap" }
        expect(swap.exists_in_probed?).to eq false
        # All preexisting partitions have some label
        expect(swap.filesystem.label).to be_empty
      end
    end

    before { settings.candidate_devices = [candidate] }

    context "when swap_reuse is set to :any" do
      before { settings.swap_reuse = :any }

      context "and there is no swap in the candidate devices" do
        let(:candidate) { "/dev/sda" }

        include_examples "reuse best swap"
      end

      context "and there is a swap device (not the best regarding size) in the candidate devices" do
        let(:candidate) { "/dev/sdc" }

        include_examples "reuse best swap"
      end

      context "and the best swap device in the candidate devices" do
        let(:candidate) { "/dev/dasdb" }

        include_examples "reuse best swap"
      end
    end

    context "when swap_reuse is set to :none" do
      before { settings.swap_reuse = :none }

      context "and there is no swap in the candidate devices" do
        let(:candidate) { "/dev/sda" }

        include_examples "new swap"
      end

      context "and there is a swap device (not the biggest one) in the candidate devices" do
        let(:candidate) { "/dev/sdc" }

        include_examples "new swap"
      end

      context "and the biggest swap device in the candidate devices" do
        let(:candidate) { "/dev/dasdb" }

        include_examples "new swap"
      end
    end

    context "when swap_reuse is set to :candidate" do
      before { settings.swap_reuse = :candidate }

      context "and there is no swap in the candidate devices" do
        let(:candidate) { "/dev/sda" }

        include_examples "new swap"
      end

      context "and there is a swap device (not the biggest one) in the candidate devices" do
        let(:candidate) { "/dev/sdc" }

        it "reuses the swap partition from the candidate devices" do
          proposal.propose
          swap = proposal.devices.partitions.find { |p| p.filesystem&.mount_path == "swap" }
          expect(swap.exists_in_probed?).to eq true
          expect(swap.name).to eq "/dev/sdc2"
          expect(swap.filesystem.label).to eq "swap_sdc"
        end
      end

      context "and the biggest swap device in the candidate devices" do
        let(:candidate) { "/dev/dasdb" }

        include_examples "reuse best swap"
      end
    end
  end
end
