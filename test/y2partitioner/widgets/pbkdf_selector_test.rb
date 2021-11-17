#!/usr/bin/env rspec
# Copyright (c) [2021] SUSE LLC
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
require "y2partitioner/widgets/pbkdf_selector"

describe Y2Partitioner::Widgets::PbkdfSelector do
  subject(:widget) { described_class.new(controller) }

  let(:controller) { double("Controllers::Encryption", pbkdf: initial_pbkdf) }
  let(:initial_pbkdf) { "pbkdf2" }

  include_examples "CWM::ComboBox"

  describe "#init" do
    it "sets the current pbkdf value" do
      expect(widget).to receive(:value=).with(initial_pbkdf)

      widget.init
    end
  end

  describe "#value" do
    let(:selected_pbkdf) { "argon2i" }

    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(widget.widget_id), :Value)
        .and_return(selected_pbkdf)
    end

    it "returns the selected encryption method" do
      expect(widget.value).to eq(selected_pbkdf)
    end
  end

  describe "#items" do
    it "includes all available methods" do
      items = widget.items.map(&:first)

      expect(items).to contain_exactly("argon2i", "argon2id", "pbkdf2")
    end
  end

  describe "#store" do
    let(:selected_pbkdf) { "argon2id" }

    before do
      allow(Yast::UI).to receive(:QueryWidget)
        .with(Id(widget.widget_id), :Value)
        .and_return(selected_pbkdf)
    end

    it "sets the selected pbkdf" do
      expect(controller).to receive(:pbkdf=).with(selected_pbkdf)

      widget.store
    end
  end
end
