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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/btrfs_subvolumes"

describe Y2Partitioner::Widgets::BtrfsSubvolumes do
  before do
    devicegraph_stub("mixed_disks_btrfs.yml")
  end

  subject { described_class.new(filesystem) }

  let(:filesystem) do
    device_graph = Y2Partitioner::DeviceGraphs.instance.current
    device_graph.filesystems.detect { |f| f.type.is?(:btrfs) }
  end

  include_examples "CWM::CustomWidget"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a table for the btrfs subvolumes" do
      table = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BtrfsSubvolumesTable) }
      expect(table).to_not be_nil
    end

    it "shows a button to add a new btrfs subvolume" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BtrfsSubvolumesAddButton) }
      expect(button).to_not be_nil
    end

    it "shows a button to delete a btrfs subvolume" do
      button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BtrfsSubvolumesDeleteButton) }
      expect(button).to_not be_nil
    end
  end

  describe "#handle" do
    context "for a :help event" do
      let(:event) { { "ID" => :help } }

      it "shows the help popup" do
        expect(Yast::Wizard).to receive(:ShowHelp)
        subject.handle(event)
      end
    end
  end
end
