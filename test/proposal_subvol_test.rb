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
require_relative "support/proposal_examples"
require_relative "support/proposal_context"

# How to generate the files:
#   cd ../examples
#   ./device_demo.rb --yaml <input_file> --propose

describe Y2Storage::Proposal do
  describe "#propose with subvolumes" do
    include_context "proposal"

    let(:architecture) { :x86 }
    # subvol needs to be set before settings
    let(:subvol ) { true }
    subject(:proposal) { described_class.new(settings: settings) }

    context "in a PC with no partition table" do
      let(:scenario) { "empty_hard_disk_50GiB" }
      let(:expected_scenario) { "empty_hard_disk_gpt_50GiB" }
      include_examples "partition-based proposed layouts"
      # include_examples "LVM-based proposed layouts"
    end
  end
end
