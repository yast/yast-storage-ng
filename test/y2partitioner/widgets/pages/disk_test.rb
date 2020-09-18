#!/usr/bin/env rspec

# Copyright (c) [2017-2020] SUSE LLC
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

describe Y2Partitioner::Widgets::Pages::Disk do
  before do
    devicegraph_stub(scenario)
  end

  let(:scenario) { "one-empty-disk.yml" }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(disk, pager) }

  let(:disk) { current_graph.disks.first }

  let(:pager) { double("Pager") }

  include_examples "CWM::Page"

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    context "when the device is neither BIOS RAID nor multipath" do
      it "shows a disk tab" do
        expect(Y2Partitioner::Widgets::Pages::DiskTab).to receive(:new)
        subject.contents
      end

      it "shows a partitions tab" do
        expect(Y2Partitioner::Widgets::PartitionsTab).to receive(:new)
        subject.contents
      end

      it "does not show a used devices tab" do
        expect(Y2Partitioner::Widgets::UsedDevicesTab).to_not receive(:new)
        subject.contents
      end
    end

    context "when the device is a BIOS RAID" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }

      let(:disk) { current_graph.bios_raids.first }

      it "shows a disk tab" do
        expect(Y2Partitioner::Widgets::Pages::DiskTab).to receive(:new)
        subject.contents
      end

      it "shows a partitions tab" do
        expect(Y2Partitioner::Widgets::PartitionsTab).to receive(:new)
        subject.contents
      end

      it "shows a used devices tab" do
        expect(Y2Partitioner::Widgets::UsedDevicesTab).to receive(:new)
        subject.contents
      end
    end

    context "when the device is a multipath" do
      let(:scenario) { "empty-dasd-and-multipath.xml" }

      let(:disk) { current_graph.multipaths.first }

      it "shows a disk tab" do
        expect(Y2Partitioner::Widgets::Pages::DiskTab).to receive(:new)
        subject.contents
      end

      it "shows a partitions tab" do
        expect(Y2Partitioner::Widgets::PartitionsTab).to receive(:new)
        subject.contents
      end

      it "shows a used devices tab" do
        expect(Y2Partitioner::Widgets::UsedDevicesTab).to receive(:new)
        subject.contents
      end
    end
  end

  describe Y2Partitioner::Widgets::Pages::DiskTab do
    subject { described_class.new(disk) }

    include_examples "CWM::Tab"

    describe "#contents" do
      let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

      it "shows the description of the disk" do
        description = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DiskDeviceDescription) }
        expect(description).to_not be_nil
      end

      context "and the device can be used as a block device" do
        let(:disk) { current_graph.disks.first }

        it "shows a button for editing the device" do
          button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDeviceEditButton) }

          expect(button).to_not be_nil
        end

        it "shows a button to create a new partition table" do
          button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::PartitionTableAddButton) }

          expect(button).to_not be_nil
        end
      end

      context "and the device cannot be used as a block device" do
        let(:scenario) { "dasd_50GiB" }

        let(:disk) { current_graph.dasds.first }

        it "does not show a button for editing the device" do
          button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDeviceEditButton) }

          expect(button).to be_nil
        end

        it "shows a button to create a new partition table" do
          button = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::PartitionTableAddButton) }

          expect(button).to_not be_nil
        end
      end
    end
  end
end
