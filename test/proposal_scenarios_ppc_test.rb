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
require_relative "support/proposal_context"

describe Y2Storage::Proposal do
  describe "#propose" do
    using Y2Storage::Refinements::TestDevicegraph
    using Y2Storage::Refinements::SizeCasts
    using Y2Storage::Refinements::DevicegraphLists

    include_context "proposal"

    let(:architecture) { :ppc }
    let(:scenario) { "empty_hard_disk_50GiB" }

    context "in a PPC64 bare metal (PowerNV)" do
      let(:ppc_power_nv) { true }
      let(:expected_scenario) { "ppc_power_nv" }

      context "if requires a /boot partition" do
        let(:lvm) { true }

        it "creates a /boot partition" do
          proposal.propose
          expect(proposal.devices.to_str).to eq expected.to_str
        end
      end
    end

    context "in a PPC64 non-PowerNV" do
      let(:ppc_power_nv) { false }
      let(:expected_scenario) { "ppc_non_power_nv" }

      context "if requires a PReP partition" do
        let(:lvm) { false }

        it "creates a PReP partition" do
          proposal.propose
          expect(proposal.devices.to_str).to eq expected.to_str
        end
      end

      context "if requires /boot and PReP partitions" do
        let(:lvm) { true }

        it "creates /boot and PReP partitions" do
          proposal.propose
          expect(proposal.devices.to_str).to eq expected.to_str
        end
      end
    end
  end
end
