#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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

require "y2storage/refinements"

RSpec.shared_examples "proposed layout" do
  it "proposes the expected layout" do
    proposal.propose
    expect(proposal.devices.to_str).to eq expected.to_str
  end
end

RSpec.shared_examples "LVM-based proposed layouts" do
  context "using LVM" do
    let(:lvm) { true }
    let(:encrypt) { false }

    context "with a separate home" do
      let(:separate_home) { true }
      include_examples "proposed layout"
    end

    context "without separate home" do
      let(:separate_home) { false }
      include_examples "proposed layout"
    end
  end
end

RSpec.shared_examples "partition-based proposed layouts" do
  context "not using LVM" do
    let(:lvm) { false }

    context "with a separate home" do
      let(:separate_home) { true }
      include_examples "proposed layout"
    end

    context "without separate home" do
      let(:separate_home) { false }
      include_examples "proposed layout"
    end
  end
end

RSpec.shared_examples "Encrypted LVM-based proposed layouts" do
  context "using Encrypted LVM" do
    let(:lvm) { true }
    let(:encrypt) { true }

    context "with a separate home" do
      let(:separate_home) { true }
      include_examples "proposed layout"
    end

    context "without separate home" do
      let(:separate_home) { false }
      include_examples "proposed layout"
    end
  end
end

RSpec.shared_examples "Encrypted partition-based proposed layouts" do
  context "not using LVM but using encryption" do
    let(:lvm) { false }
    let(:encrypt) { true }

    context "with a separate home" do
      let(:separate_home) { true }
      include_examples "proposed layout"
    end

    context "without separate home" do
      let(:separate_home) { false }
      include_examples "proposed layout"
    end
  end
end

RSpec.shared_examples "all proposed layouts" do
  include_examples "LVM-based proposed layouts"
  include_examples "Encrypted LVM-based proposed layouts"
  include_examples "partition-based proposed layouts"
  include_examples "Encrypted partition-based proposed layouts"
end
