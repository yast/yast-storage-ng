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
require "y2partitioner/widgets/pervasive_key_type_selector"

describe Y2Partitioner::Widgets::PervasiveKeyTypeSelector do
  subject(:widget) { described_class.new(controller, apqn1, enable: start_enabled) }

  let(:apqn1) { apqn_mock("01.0001", "0x123") }
  let(:apqn2) { apqn_mock("03.0001", "0xabcdefg", ep11: true) }

  let(:controller) do
    double("Controllers::Encryption", find_apqn: apqn1)
  end

  let(:start_enabled) { true }

  include_examples "CWM::AbstractWidget"

  describe "#init" do
    before do
      allow(Y2Partitioner::Widgets::PervasiveKeyTypeSelector::CcaTypeSelector)
        .to receive(:new).and_return(cca_select)
    end

    let(:cca_select) { Y2Partitioner::Widgets::PervasiveKeyTypeSelector::CcaTypeSelector.new }

    context "if the widget is initially enabled" do
      let(:start_enabled) { true }

      it "enables the internal selector" do
        expect(cca_select).to receive(:enable)
        widget.init
      end
    end

    context "if the widget is initially disabled" do
      let(:start_enabled) { false }

      it "disables the internal selector" do
        expect(cca_select).to receive(:disable)
        widget.init
      end
    end
  end
end

describe Y2Partitioner::Widgets::PervasiveKeyTypeSelector::CcaTypeSelector do
  include_examples "CWM::ComboBox"
end
