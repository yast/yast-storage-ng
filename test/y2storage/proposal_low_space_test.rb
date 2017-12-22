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
    let(:architecture) { :x86 }

    context "in a PC with a small (25GiB) disk" do
      let(:scenario) { "empty_hard_disk_gpt_25GiB" }
      let(:expected_scenario) { "empty_hard_disk_gpt_25GiB" }
      include_examples "partition-based proposed layouts"
      include_examples "LVM-based proposed layouts"
    end
  end

  # Regression tests (bsc#1058027)
  describe ".initial" do
    before do
      Y2Storage::StorageManager.create_test_instance
    end

    let(:devicegraph) { Y2Storage::StorageManager.instance.probed }

    context "with a disk of 10 GiB" do
      before do
        sda = Y2Storage::Disk.create(devicegraph, "/dev/sda")
        sda.size = Y2Storage::DiskSize.GiB(10)
      end

      it "produces a proposal" do
        proposal = described_class.initial
        expect(proposal.devices).to_not be_nil
      end
    end

    context "with two disks of 10 GiB and 2 GiB" do
      before do
        sda = Y2Storage::Disk.create(devicegraph, "/dev/sda")
        sda.size = Y2Storage::DiskSize.GiB(10)

        sdb = Y2Storage::Disk.create(devicegraph, "/dev/sdb")
        sdb.size = Y2Storage::DiskSize.GiB(2)
      end

      it "produces a proposal" do
        proposal = described_class.initial
        expect(proposal.devices).to_not be_nil
      end
    end
  end
end
