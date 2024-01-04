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

require_relative "../spec_helper"
require "storage"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  using Y2Storage::Refinements::SizeCasts
  let(:architecture) { :x86 }

  include_context "proposal"

  describe "#propose" do
    subject(:proposal) { described_class.new(settings:) }

    # regession test for bsc#1078691:
    #   - root and swap are both logical partitions
    #   - root is before swap
    #   - swap can be reused (is big enough)
    #   - the old root will be deleted and the space reused (so swap
    #     changes its name in between)
    context "when swap is reused but changes its device name" do
      let(:scenario) { "bug_1078691.xml" }
      let(:settings_format) { :ng }
      let(:control_file) { "bug_1078691.xml" }
      let(:windows_partitions) { {} }

      it "includes a partition for '/'" do
        settings.candidate_devices = ["/dev/sda"]
        proposal.propose
        filesystems = proposal.devices.filesystems
        expect(filesystems.map { |x| x.mount_point && x.mount_point.path }).to include "/"
      end
    end
  end
end
