#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018-2019] SUSE LLC
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
require "y2partitioner/widgets/device_buttons_set"
require "y2partitioner/widgets/overview"

describe Y2Partitioner::Widgets::DeviceButtonsSet do
  before { devicegraph_stub(scenario) }

  let(:scenario) { "nested_md_raids" }
  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:pager) { Y2Partitioner::Widgets::OverviewTreePager.new("hostname") }

  subject(:widget) { described_class.new(pager) }

  include_examples "CWM::CustomWidget"

  describe "#contents" do
    it "returns an initially empty replace point" do
      contents = widget.contents
      expect(contents.value).to eq :ReplacePoint
      expect(contents.params.last.value).to eq :Empty
    end
  end

  describe "#device=" do
    context "when targeting a partition" do
      let(:device) { device_graph.partitions.first }

      it "replaces the content with buttons to modify and delete" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to contain_exactly(
            Y2Partitioner::Widgets::DeviceButtonsSet::ButtonsBox,
            Y2Partitioner::Widgets::PartitionModifyButton,
            Y2Partitioner::Widgets::DeviceDeleteButton
          )
        end

        widget.device = device
      end
    end

    context "when targeting an MD" do
      let(:device) { device_graph.software_raids.first }

      it "replaces the content with buttons to modify, to delete and to manage partitions" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to contain_exactly(
            Y2Partitioner::Widgets::DeviceButtonsSet::ButtonsBox,
            Y2Partitioner::Widgets::MdModifyButton,
            Y2Partitioner::Widgets::PartitionsButton,
            Y2Partitioner::Widgets::DeviceDeleteButton
          )
        end

        widget.device = device
      end
    end

    context "when targeting a disk device" do
      let(:device) { device_graph.disks.first }

      it "replaces the content with buttons to modify and to manage partitions" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to contain_exactly(
            Y2Partitioner::Widgets::DeviceButtonsSet::ButtonsBox,
            Y2Partitioner::Widgets::DiskModifyButton,
            Y2Partitioner::Widgets::PartitionsButton
          )
        end

        widget.device = device
      end
    end

    context "when targeting a Bcache device" do
      let(:scenario) { "bcache2.xml" }
      let(:device) { device_graph.find_by_name("/dev/bcache0") }

      it "replaces the content with buttons to modify, to delete and to manage partitions" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to contain_exactly(
            Y2Partitioner::Widgets::DeviceButtonsSet::ButtonsBox,
            Y2Partitioner::Widgets::BcacheModifyButton,
            Y2Partitioner::Widgets::DeviceDeleteButton,
            Y2Partitioner::Widgets::PartitionsButton
          )
        end

        widget.device = device
      end
    end

    context "when targeting a Xen virtual partition (stray block device)" do
      let(:scenario) { "xen-partitions.xml" }
      let(:device) { device_graph.stray_blk_devices.first }

      it "replaces the content with a single button to edit the device" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to contain_exactly(
            Y2Partitioner::Widgets::DeviceButtonsSet::ButtonsBox,
            Y2Partitioner::Widgets::BlkDeviceEditButton
          )
        end

        widget.device = device
      end
    end

    context "when targeting a volume group" do
      let(:scenario) { "lvm-two-vgs" }
      let(:device) { device_graph.lvm_vgs.first }

      it "replaces the content with buttons to modify, to delete and to manage LVs" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to contain_exactly(
            Y2Partitioner::Widgets::DeviceButtonsSet::ButtonsBox,
            Y2Partitioner::Widgets::LvmVgModifyButton,
            Y2Partitioner::Widgets::LvmLogicalVolumesButton,
            Y2Partitioner::Widgets::DeviceDeleteButton
          )
        end

        widget.device = device
      end
    end

    context "when targeting a logical volume" do
      let(:scenario) { "lvm-two-vgs" }
      let(:device) { device_graph.lvm_lvs.first }

      it "replaces the content with buttons to modify and delete the LV" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to contain_exactly(
            Y2Partitioner::Widgets::DeviceButtonsSet::ButtonsBox,
            Y2Partitioner::Widgets::LvmLvModifyButton,
            Y2Partitioner::Widgets::DeviceDeleteButton
          )
        end

        widget.device = device
      end
    end

    context "when targeting a BTRFS filesystem" do
      let(:scenario) { "mixed_disks" }
      let(:device) { device_graph.find_by_name("/dev/sdb2").filesystem }

      it "replaces the content with a single button to edit the filesystem" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to contain_exactly(
            Y2Partitioner::Widgets::DeviceButtonsSet::ButtonsBox,
            Y2Partitioner::Widgets::BtrfsModifyButton
          )
        end

        widget.device = device
      end
    end

    context "when an unsupported device is used" do
      let(:device) { device_graph.filesystems.first }

      it "replaces the content with an empty widget" do
        expect(widget).to receive(:replace) do |content|
          widgets = Yast::CWM.widgets_in_contents([content])
          expect(widgets.map(&:class)).to eq [CWM::Empty]
        end

        widget.device = device
      end
    end
  end
end
