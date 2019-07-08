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
require "storage"
require "y2storage"

require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"
require_relative "#{TEST_PATH}/support/candidate_devices_context"

describe Y2Storage::InitialGuidedProposal do
  using Y2Storage::Refinements::SizeCasts

  include_context "proposal"

  let(:architecture) { :x86 }

  let(:scenario) { "empty_hard_disk_gpt_25GiB" }

  subject(:proposal) { described_class.new(settings: settings) }

  describe ".new" do
    context "when settings are not passed" do
      it "reads the settings for the current product (control.xml)" do
        expect(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
          .and_call_original

        described_class.new(settings: nil)
      end
    end
  end

  describe "#propose" do
    let(:ng_partitioning_section) do
      {
        "partitioning" => { "proposal" => {}, "volumes" => volumes_spec }
      }
    end

    let(:volumes_spec) do
      [
        {
          "mount_point"  => "/",
          "fs_type"      => "ext4",
          "desired_size" => "10GiB",
          "min_size"     => "8GiB",
          "max_size"     => "20GiB"
        },
        {
          "mount_point"  => "/home",
          "fs_type"      => "xfs",
          "desired_size" => "20GiB",
          "min_size"     => "10GiB",
          "max_size"     => "40GiB"
        },
        {
          "mount_point"           => "swap",
          "fs_type"               => "swap",
          "desired_size"          => "2GiB",
          "min_size"              => "1GiB",
          "max_size"              => "2GiB",
          "proposed_configurable" => swap_optional,
          "disable_order"         => 1
        }
      ]
    end

    let(:swap_optional) { true }

    context "when settings has legacy format" do
      it "uses the legacy settings generator to calculate the settings" do
        expect(Y2Storage::Proposal::SettingsGenerator::Legacy).to receive(:new).and_call_original

        proposal.propose
      end
    end

    context "when settings has ng format" do
      let(:control_file_content) { ng_partitioning_section }

      it "uses the ng settings generator to calculate the settings" do
        expect(Y2Storage::Proposal::SettingsGenerator::Ng).to receive(:new).and_call_original

        proposal.propose
      end
    end

    context "when no candidate devices are given" do
      include_context "candidate devices"

      let(:candidate_devices) { nil }

      let(:control_file_content) { ng_partitioning_section }

      let(:sda_usb) { true }

      it "uses the first non USB device to make the proposal" do
        proposal.propose

        expect(used_devices).to contain_exactly("/dev/sdb")
      end

      context "and a proposal is not possible with the current device" do
        before do
          # root requires at least 8 GiB and home 10 GiB
          sdb.size = 5.GiB
        end

        it "uses the next non USB device to make the proposal" do
          proposal.propose

          expect(used_devices).to contain_exactly("/dev/sdc")
        end
      end

      context "and a proposal is not possible without USB devices" do
        let(:sda_usb) { false }
        let(:sdb_usb) { true }
        let(:sdc_usb) { true }

        before do
          # root requires at least 8 GiB and home 10 GiB
          sda.size = 10.GiB
        end

        it "uses the first USB device to make a proposal" do
          proposal.propose

          expect(used_devices).to contain_exactly("/dev/sdb")
        end

        context "and a proposal is not possible with the current USB device" do
          before do
            # root requires at least 8 GiB and home 10 GiB
            sdb.size = 5.GiB
          end

          it "uses the next USB device to make the proposal" do
            proposal.propose

            expect(used_devices).to contain_exactly("/dev/sdc")
          end
        end
      end

      context "and a proposal is not possible with any individual device" do
        let(:swap_optional) { false }

        before do
          sda.size = 12.GiB
          sdb.size = 15.GiB
          sdc.size = 3.GiB
        end

        it "allocates the root device in the biggest device" do
          proposal.propose

          expect(disk_for("/").name).to eq "/dev/sdb"
        end

        context "and swap is optional" do
          let(:swap_optional) { true }

          it "uses all the devices to make the proposal" do
            proposal.propose

            expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
          end

          it "allocates the swap partition in a separate device" do
            proposal.propose

            expect(disk_for("swap").name).to eq "/dev/sdc"
          end
        end

        context "and swap is mandatory" do
          let(:swap_optional) { false }

          it "uses all the devices to make the proposal" do
            proposal.propose

            expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb", "/dev/sdc")
          end

          it "allocates the swap partition in a separate device" do
            proposal.propose

            expect(disk_for("swap").name).to eq "/dev/sdc"
          end
        end
      end
    end

    context "when some candidate devices are given" do
      include_context "candidate devices"

      let(:candidate_devices) { ["/dev/sda", "/dev/sdb"] }

      let(:control_file_content) { ng_partitioning_section }

      let(:sda_usb) { true }

      it "uses the biggest candidate device to make the proposal" do
        proposal.propose

        expect(disk_for("/").name).to eq "/dev/sda"
      end

      context "and a proposal is not possible with any individual candidate device" do
        before do
          sda.size = 12.GiB
          sdb.size = 15.GiB
          sdc.size = 3.GiB
        end

        it "uses all the candidate devices to make a proposal" do
          proposal.propose

          expect(used_devices).to contain_exactly("/dev/sda", "/dev/sdb")
        end
      end
    end

    context "when a proposal is not possible with the current settings" do
      include_context "candidate devices"

      let(:candidate_devices) { ["/dev/sda"] }

      let(:control_file_content) { ng_partitioning_section }

      before do
        sda.size = 18.5.GiB
      end

      it "makes the proposal by disabling properties before moving to another candidate device" do
        proposal.propose

        partitions = proposal.devices.partitions
        mount_points = partitions.map(&:filesystem_mountpoint).compact

        expect(used_devices).to contain_exactly("/dev/sda")
        expect(mount_points).to_not include("swap")
      end
    end

    # Test, at hight level, that settings are reset between candidates
    #
    # Related to bsc#113092, settings must be **correctly** reset after moving to another (group
    # of) candidate device(s). To check that, the first candidate will be small enough to make not
    # possible the proposal on it even **after adjust the initial settings**, expecting to have a
    # valid proposal **with original settings** in the second candidate.
    context "when a proposal is not possible for a candidate even after adjust the settings" do
      include_context "candidate devices"

      let(:candidate_devices) { ["/dev/sda", "/dev/sdb"] }

      let(:control_file_content) { ng_partitioning_section }

      before do
        sda.size = 2.GiB
      end

      it "resets the settings before attempting a new proposal with next candidate" do
        proposal.propose

        partitions = proposal.devices.partitions
        mount_points = partitions.map(&:filesystem_mountpoint).compact

        expect(used_devices).to contain_exactly("/dev/sdb")

        # having expected mount points means that settings were reset properly, since in the
        # previous attempts swap and separated home should be deleted
        expect(mount_points).to include("swap", "/home", "/")
      end
    end

    context "when a proposal is not possible" do
      include_context "candidate devices"

      let(:candidate_devices) { ["/dev/sda"] }

      let(:control_file_content) { ng_partitioning_section }

      before do
        # root requires at least 8 GiB and home 10 GiB
        sda.size = 10.GiB
      end

      it "raises an error" do
        expect { proposal.propose }.to raise_error(Y2Storage::Error)
      end
    end
  end
end
