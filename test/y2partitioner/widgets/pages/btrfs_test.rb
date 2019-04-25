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
require "y2partitioner/widgets/pages/btrfs"

describe Y2Partitioner::Widgets::Pages::Btrfs do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(filesystem, pager) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:filesystem) { device.filesystem }

  let(:pager) { double("Pager") }

  let(:scenario) { "mixed_disks" }

  let(:device_name) { "/dev/sdb2" }

  include_examples "CWM::Page"

  describe "label" do
    context "for a non-multidevice BTRFS" do
      let(:scenario) { "mixed_disks" }

      let(:device_name) { "/dev/sdb2" }

      it "returns the base name of its block device" do
        expect(subject.label).to eq("sdb2")
      end
    end

    context "for a multidevice BTRFS" do
      let(:scenario) { "btrfs2-devicegraph.xml" }

      let(:device_name) { "/dev/sdb1" }

      it "returns the base name of its first block device followed by '+'" do
        basename = filesystem.blk_devices.first.basename
        expect(subject.label).to eq(basename + "+")
      end
    end
  end

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    it "shows a BTRFS overview tab" do
      expect(Y2Partitioner::Widgets::Pages::FilesystemTab).to receive(:new)
      subject.contents
    end

    it "shows an used devices tab" do
      expect(Y2Partitioner::Widgets::UsedDevicesTab).to receive(:new)
      subject.contents
    end
  end

  describe Y2Partitioner::Widgets::Pages::FilesystemTab do
    subject { described_class.new(filesystem) }

    include_examples "CWM::Tab"

    describe "#contents" do
      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      it "shows the description of the filesystem" do
        description = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::FilesystemDescription) }
        expect(description).to_not be_nil
      end

      it "shows a button for editing the filesystem" do
        button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BtrfsEditButton) }
        expect(button).to_not be_nil
      end
    end
  end
end
