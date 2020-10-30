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

require_relative "device_page"
require "y2partitioner/widgets/pages/disk"

describe Y2Partitioner::Widgets::Pages::Disk do
  before do
    devicegraph_stub(scenario)
  end

  let(:scenario) { "one-empty-disk.yml" }
  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:disk) { current_graph.disks.first }
  let(:pager) { double("Pager") }

  subject { described_class.new(disk, pager) }

  let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }
  let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::ConfigurableBlkDevicesTable) } }

  include_examples "CWM::Page"

  describe "#contents" do
    context "when the device is neither BIOS RAID nor multipath" do
      it "shows a disk overview tab" do
        expect(Y2Partitioner::Widgets::OverviewTab).to receive(:new)
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

      it "shows a disk overview tab" do
        expect(Y2Partitioner::Widgets::OverviewTab).to receive(:new)
        subject.contents
      end

      it "shows a used devices tab" do
        expect(Y2Partitioner::Widgets::UsedDevicesTab).to receive(:new)
        subject.contents
      end

      include_examples(
        "device page",
        "Y2Partitioner::Widgets::OverviewTab",
        "Y2Partitioner::Widgets::Pages::DiskUsedDevicesTab"
      )
    end

    context "when the device is a multipath" do
      let(:scenario) { "empty-dasd-and-multipath.xml" }
      let(:disk) { current_graph.multipaths.first }

      it "shows a disk overview tab" do
        expect(Y2Partitioner::Widgets::OverviewTab).to receive(:new)
        subject.contents
      end

      it "shows a used devices tab" do
        expect(Y2Partitioner::Widgets::UsedDevicesTab).to receive(:new)
        subject.contents
      end

      include_examples(
        "device page",
        "Y2Partitioner::Widgets::OverviewTab",
        "Y2Partitioner::Widgets::Pages::DiskUsedDevicesTab"
      )
    end
  end

  describe Y2Partitioner::Widgets::Pages::DiskUsedDevicesTab do
    subject { described_class.new(device, pager) }

    let(:scenario) { "empty-dm_raids.xml" }
    let(:device) { current_graph.bios_raids.first }

    include_examples "CWM::Tab"

    describe "#contents" do
      let(:items) { column_values(table, 0) }

      context "when the device is a BIOS RAID" do
        let(:scenario) { "empty-dm_raids.xml" }

        let(:device) { current_graph.find_by_name("/dev/mapper/isw_ddgdcbibhd_test1") }

        it "shows a table with the BIOS RAID and its devices" do
          expect(table).to_not be_nil

          expect(remove_sort_keys(items)).to contain_exactly(
            "/dev/mapper/isw_ddgdcbibhd_test1",
            "/dev/sdb",
            "/dev/sdc"
          )
        end
      end

      context "when the device is a Multipath" do
        let(:scenario) { "multipath-formatted.xml" }

        let(:device) { current_graph.find_by_name("/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1") }

        it "shows a table with the Multipath and its wires" do
          expect(table).to_not be_nil

          expect(remove_sort_keys(items)).to contain_exactly(
            "/dev/mapper/0QEMU_QEMU_HARDDISK_mpath1",
            "/dev/sda",
            "/dev/sdb"
          )
        end
      end
    end
  end
end
