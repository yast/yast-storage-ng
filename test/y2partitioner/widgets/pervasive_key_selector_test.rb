#!/usr/bin/env rspec

# Copyright (c) [2025] SUSE LLC
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
require "y2partitioner/widgets/pervasive_key_selector"

describe Y2Partitioner::Widgets::PervasiveKeySelector do
  subject(:widget) { described_class.new(apqns_by_key, initial_key) }

  let(:all_apqns) { [apqn1, apqn2, apqn3, apqn4, apqn5, apqn6] }
  let(:apqns_by_key) { all_apqns.group_by(&:master_key_pattern) }
  let(:initial_key) { apqn1.master_key_pattern }

  let(:apqn1) { apqn_mock("01.0001", "0x123") }
  let(:apqn2) { apqn_mock("01.0002", "0x456") }
  let(:apqn3) { apqn_mock("02.0001", "0x123") }
  let(:apqn4) { apqn_mock("03.0001", "0xabcdefgabcde", ep11: true) }
  let(:apqn5) { apqn_mock("03.0002", "0x7654321abcde", ep11: true) }
  let(:apqn6) { apqn_mock("03.0003", "0x7654321abcde", ep11: true) }

  include_examples "CWM::ComboBox"

  describe "#init" do
    it "sets the current key value" do
      expect(widget).to receive(:value=).with(initial_key)

      widget.init
    end
  end
end
