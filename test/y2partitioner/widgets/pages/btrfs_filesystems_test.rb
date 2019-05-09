#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require "y2partitioner/widgets/pages/btrfs_filesystems"

describe Y2Partitioner::Widgets::Pages::BtrfsFilesystems do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:btrfs_filesystems) { current_graph.btrfs_filesystems }

  subject { described_class.new(btrfs_filesystems, pager) }

  let(:pager) { double("OverviewTreePager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a table with all the btrfs filesystems" do
      table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) }

      expect(table).to_not be_nil

      id_values = btrfs_filesystems.map(&:blk_device_basename)
      first_column = table.items.map { |i| i[1] }

      expect(first_column).to contain_exactly(*id_values)
    end

    it "shows a buttons set" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DeviceButtonsSet) }
      expect(button).to_not be_nil
    end
  end
end
