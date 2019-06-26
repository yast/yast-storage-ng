#!/usr/bin/env rspec
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
require "y2partitioner/widgets/pages"

describe Y2Partitioner::Widgets::Pages::MdRaid do
  before { devicegraph_stub("md_raid") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:pager) { double("Pager") }

  let(:md) { current_graph.md_raids.first }

  subject { described_class.new(md, pager) }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a MD tab" do
      expect(Y2Partitioner::Widgets::Pages::MdTab).to receive(:new)
      subject.contents
    end

    it "shows a used devices tab" do
      expect(Y2Partitioner::Widgets::UsedDevicesTab).to receive(:new)
      subject.contents
    end

    it "shows a partitions tab" do
      expect(Y2Partitioner::Widgets::PartitionsTab).to receive(:new)
      subject.contents
    end
  end

  describe Y2Partitioner::Widgets::Pages::MdTab do
    subject { described_class.new(md) }

    include_examples "CWM::Tab"

    describe "#contents" do
      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      it "shows the description of the MD RAID" do
        description = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::MdDescription) }
        expect(description).to_not be_nil
      end

      it "shows a button to edit the raid" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDeviceEditButton) }
        expect(button).to_not be_nil
      end

      it "shows a button to delete the raid" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceDeleteButton) }
        expect(button).to_not be_nil
      end

      it "shows a button for creating a new partition table" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::PartitionTableAddButton) }
        expect(button).to_not be_nil
      end
    end
  end

  describe Y2Partitioner::Widgets::Pages::MdDevicesTab do
    subject { described_class.new(md, pager) }

    include_examples "CWM::Tab"

    describe "#contents" do
      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      it "shows a button to edit the used devices" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::UsedDevicesEditButton) }
        expect(button).to_not be_nil
      end
    end
  end
end
