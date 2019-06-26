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
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  describe ".initial" do
    include_context "proposal"

    context "with Xen devices representing virtual disks and partitions" do
      let(:scenario) { "xen-disks-and-partitions.xml" }

      it "makes a proposal that doesn't use the virtual partitions (stray devices)" do
        proposal = described_class.initial
        used_devices = proposal.devices.actiongraph.compound_actions.map(&:target_device)
        # Leave the Btrfs subvolumes out, they are noise for our purposes
        device_names = used_devices.reject { |dev| dev.is?(:btrfs_subvolume) }.map(&:name)

        used_stray_device = device_names.find { |name| name.start_with?("/dev/xvda") }
        expect(used_stray_device).to be_nil
      end
    end

    context "if there are only Xen virtual partitions (no disks)" do
      let(:scenario) { "xen-partitions.xml" }

      it "fails to make a successful proposal" do
        proposal = described_class.initial
        expect(proposal.failed?).to eq true
      end
    end
  end
end
