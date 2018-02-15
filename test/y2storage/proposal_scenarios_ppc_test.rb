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

require_relative "spec_helper"
require "storage"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  describe "#propose" do
    include_context "proposal"

    subject(:proposal) { described_class.new(settings: settings) }
    let(:architecture) { :ppc }
    let(:scenario) { "empty_hard_disk_50GiB" }

    context "in a PPC64 bare metal (PowerNV)" do
      let(:ppc_power_nv) { true }
      let(:expected_scenario) { "ppc_power_nv" }

      context "if requires a /boot partition" do
        let(:lvm) { true }

        include_examples "proposed layout"
      end
    end

    context "in a PPC64 non-PowerNV" do
      let(:ppc_power_nv) { false }
      let(:expected_scenario) { "ppc_non_power_nv" }

      context "using plain partitions" do
        let(:lvm) { false }
        include_examples "proposed layout"
      end

      context "not using plain partitions" do
        let(:lvm) { true }
        include_examples "proposed layout"
      end
    end

    # Regression test for bug#1067670 in which no proposal was provided
    context "if the only available device is directly formatted (no partition table)" do
      let(:scenario) { "multipath-formatted.xml" }
      let(:ppc_power_nv) { false }

      context "using LVM" do
        let(:lvm) { true }

        it "deletes the existing filesystem and proposes a new LVM layout" do
          expect(fake_devicegraph.partitions).to be_empty
          proposal.propose
          expect(proposal.devices.partitions).to_not be_empty
          expect(proposal.devices.lvm_vgs).to_not be_empty
        end
      end

      context "not using LVM" do
        let(:lvm) { false }

        it "deletes the existing filesystem and proposes a new partition-based layout" do
          expect(fake_devicegraph.partitions).to be_empty
          proposal.propose
          expect(proposal.devices.partitions).to_not be_empty
          expect(proposal.devices.lvm_vgs).to be_empty
        end
      end
    end

    # Regression test for bug#1076851 which proposed /boot at the beginning of
    # disk (instead of PReP)
    context "using the whole disk with LVM" do
      let(:scenario) { "bug_1076851.xml" }
      let(:ppc_power_nv) { false }
      let(:lvm) { true }
      before do
        settings.linux_delete_mode = :all
        settings.other_delete_mode = :all
      end

      it "proposes PReP at the beginning of the disk" do
        proposal.propose
        sda1 = proposal.devices.find_by_name("/dev/sda1")
        expect(sda1.id).to eq Y2Storage::PartitionId::PREP
        expect(sda1.region.start).to eq 2048
        expect(sda1.filesystem).to be_nil
      end
    end
  end
end
