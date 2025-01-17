#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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

require_relative "../test_helper"
require "cwm/rspec"
require "y2partitioner/widgets/apqn_selector"

describe Y2Partitioner::Widgets do
  let(:apqn1) { apqn_mock("01.0001", "0x123") }
  let(:apqn2) { apqn_mock("01.0002", "0x456") }
  let(:apqn3) { apqn_mock("02.0001", "0x123") }
  let(:apqn4) { apqn_mock("03.0001", "0xabcdefg", ep11: true) }

  describe Y2Partitioner::Widgets::ApqnSelector do
    subject(:widget) { described_class.new(apqns_by_key, initial_key, initial_apqns) }

    let(:all_apqns) { [apqn1, apqn2, apqn3, apqn4] }
    let(:apqns_by_key) { all_apqns.group_by(&:master_key_pattern) }
    let(:initial_key) { apqn1.master_key_pattern }
    let(:initial_apqns) { [apqn1] }

    include_examples "CWM::AbstractWidget"

    before do
      allow(Y2Partitioner::Widgets::ApqnSelector::ApqnMultiSelector).to receive(:new).and_return(multi)
    end

    let(:multi) { Y2Partitioner::Widgets::ApqnSelector::ApqnMultiSelector.new("id", [], []) }

    describe "#enable" do
      it "forwards the call to the inner widget" do
        expect(multi).to receive(:enable)
        widget.enable
      end
    end

    describe "#disable" do
      it "forwards the call to the combo box" do
        expect(multi).to receive(:disable)
        widget.disable
      end
    end
  end

  describe Y2Partitioner::Widgets::ApqnSelector::ApqnMultiSelector do
    subject(:widget) { described_class.new("id", [apqn1, apqn3], [apqn1]) }

    include_examples "CWM::AbstractWidget"

    describe "#init" do
      it "sets the current key value" do
        expect(widget).to receive(:value=).with([apqn1])

        widget.init
      end
    end

    describe "#items" do
      it "includes one entry per each APQN" do
        expect(widget.items).to eq [[apqn1, apqn1], [apqn3, apqn3]]
      end
    end
  end
end
