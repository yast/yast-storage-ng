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

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages/lvm_lv"

describe Y2Partitioner::Widgets::Pages::LvmLv do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:lvm_lv) { current_graph.lvm_lvs.first }

  subject { described_class.new(lvm_lv) }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows the description of the lv" do
      description = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::LvmLvDescription) }
      expect(description).to_not be_nil
    end

    it "shows a button to edit the lv" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDeviceEditButton) }
      expect(button).to_not be_nil
    end

    it "shows a resize button" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceResizeButton) }
      expect(button).to_not be_nil
    end

    it "shows a delete button" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceDeleteButton) }
      expect(button).to_not be_nil
    end
  end
end
