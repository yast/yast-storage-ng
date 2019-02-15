#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017-2019] SUSE LLC
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

require_relative "../../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::Bcache do
  before do
    devicegraph_stub(scenario)
  end

  let(:architecture) { :x86_64 } # bcache is only supported on x86_64

  let(:scenario) { "bcache2.xml" }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(bcache, pager) }

  let(:bcache) { current_graph.find_by_name(device_name) }

  let(:device_name) { "/dev/bcache0" }

  let(:pager) { double("Pager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a bcache overview tab" do
      expect(Y2Partitioner::Widgets::Pages::BcacheTab).to receive(:new)
      subject.contents
    end

    it "shows a partitions tab" do
      expect(Y2Partitioner::Widgets::PartitionsTab).to receive(:new)
      subject.contents
    end
  end

  describe Y2Partitioner::Widgets::Pages::BcacheTab do
    subject { described_class.new(bcache) }

    include_examples "CWM::Tab"

    describe "#contents" do
      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      it "shows the description of the device" do
        description = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BcacheDeviceDescription) }
        expect(description).to_not be_nil
      end

      it "shows a button for editing the device" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDeviceEditButton) }
        expect(button).to_not be_nil
      end

      it "shows a button for changing the caching options" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BcacheEditButton) }
        expect(button).to_not be_nil
      end

      it "shows a button for deleting the device" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceDeleteButton) }
        expect(button).to_not be_nil
      end

      it "shows a button for configuring the partition table" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::PartitionTableAddButton) }
        expect(button).to_not be_nil
      end
    end
  end
end
