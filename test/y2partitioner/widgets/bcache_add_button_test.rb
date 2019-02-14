#!/usr/bin/env rspec
# encoding: utf-8

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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/bcache_add_button"

describe Y2Partitioner::Widgets::BcacheAddButton do
  subject(:button) { described_class.new }

  let(:architecture ) { :x86_64 } # bcache is only supported on x86_64

  before do
    devicegraph_stub("bcache1.xml")

    allow(Y2Partitioner::Actions::AddBcache).to receive(:new)
      .and_return(double(run: action_result))
  end

  let(:action_result) { :finish }

  include_examples "CWM::PushButton"

  describe "#handle" do
    it "starts an action to create a bcache device" do
      expect(Y2Partitioner::Actions::AddBcache).to receive(:new)

      button.handle
    end

    context "if the action returns :finish" do
      let(:action_result) { :finish }

      it "returns :redraw" do
        expect(button.handle).to eq(:redraw)
      end
    end

    context "if the action does not return :finish" do
      let(:action_result) { :back }

      it "returns nil" do
        expect(button.handle).to be_nil
      end
    end
  end
end
