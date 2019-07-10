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
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  describe ".initial" do
    include_context "proposal"

    subject(:proposal) { described_class.initial(settings: settings) }

    let(:architecture) { :x86 }

    let(:settings_format) { :ng }

    let(:control_file) { "kvm-role-like.xml" }

    # Test representing an scenario found during the development of SLE15.
    # The resulting proposal didn't look that nice to human eyes because it
    # refused to use some disk space just to keep all the new partitions together
    # (something the proposal considered more important than it really is).
    # This test was added to in order to adjust the proposal criteria to something
    # that looks more reasonable and to make sure it remains reasonable over time.
    context "distributing three partitions in two spaces and reusing another" do
      let(:scenario) { "kvm_role_scenario" }
      let(:expected_scenario) { "kvm_role_scenario" }

      it "proposes the expected layout, optimizing sizes based on the weights" do
        expect(proposal.devices.to_str).to eq expected.to_str
      end
    end
  end
end
