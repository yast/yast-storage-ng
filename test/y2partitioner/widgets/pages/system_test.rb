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
require "y2partitioner/widgets/overview"

describe Y2Partitioner::Widgets::Pages::System do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new("hostname", pager) }

  let(:pager) { double("OverviewTreePager", invalidated_pages: []) }

  let(:scenario) { "mixed_disks.yml" }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::Page"

  # Widget with the list of devices
  def find_table(widgets)
    widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::BlkDevicesTable) }
  end

  # Names from the devices in the list
  def row_names(table)
    column_values(table, 0)
  end

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    let(:table) { find_table(widgets) }

    let(:items) { row_names(table) }

    it "contains a device buttons set" do
      device_buttons = widgets.find { |w| w.is_a?(Y2Partitioner::Widgets::DeviceButtonsSet) }
      expect(device_buttons).to_not be_nil
    end

    context "when there are disks" do
      let(:scenario) { "mixed_disks.yml" }

      it "contains all disks and their partitions" do
        expect(items).to contain_exactly(
          "/dev/sda", "sda1", "sda2",
          "/dev/sdb", "sdb1", "sdb2", "sdb3", "sdb4", "sdb5", "sdb6", "sdb7",
          "/dev/sdc"
        )
      end
    end

    context "when there are DASDs devices" do
      let(:scenario) { "dasd_50GiB.yml" }

      it "contains all DASDs and their partitions" do
        expect(items).to contain_exactly(
          "/dev/dasda", "dasda1"
        )
      end
    end

    context "when there are DM RAIDs" do
      let(:scenario) { "empty-dm_raids.xml" }

      it "contains all DM RAIDs" do
        expect(items).to include(
          "/dev/mapper/isw_ddgdcbibhd_test1",
          "/dev/mapper/isw_ddgdcbibhd_test2"
        )
      end

      it "does not contain devices belonging to DM RAIDs" do
        expect(items).to_not include(
          "/dev/sdb",
          "/dev/sdc"
        )
      end

      it "contains devices that does not belong to DM RAIDs" do
        expect(items).to include(
          "/dev/sda", "sda1", "sda2"
        )
      end
    end

    context "when there are BIOS MD RAIDs" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }

      it "contains all BIOS MD RAIDs" do
        expect(items).to include(
          "/dev/md/a",
          "/dev/md/b"
        )
      end

      it "does not contain devices belonging to BIOS DM RAIDs" do
        expect(items).to_not include(
          "/dev/sdb",
          "/dev/sdc",
          "/dev/sdd"
        )
      end

      it "contains devices that does not belong to BIOS DM RAIDs" do
        expect(items).to include(
          "/dev/sda", "sda1", "sda2"
        )
      end
    end

    context "when there are Software RAIDs" do
      let(:scenario) { "md_raid" }

      before do
        Y2Storage::Md.create(current_graph, "/dev/md1")
      end

      it "contains all Software RAIDs" do
        expect(items).to include(
          "/dev/md/md0",
          "/dev/md1"
        )
      end

      it "contains devices belonging to Software RAIDs" do
        expect(items).to include(
          "/dev/sda"
        )
      end
    end

    context "when there are Volume Groups" do
      let(:scenario) { "lvm-two-vgs.yml" }

      before do
        vg = Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0")
        create_thin_provisioning(vg)
      end

      it "contains all Volume Groups and their logical volumes (including thin volumes)" do
        expect(items).to include(
          "/dev/vg0", "lv1", "lv2", "pool1", "thin1", "thin2", "pool2", "thin3",
          "/dev/vg1", "lv1"
        )
      end

      it "contains devices belonging to Volume Groups" do
        expect(items).to include(
          "sda5", "sda7", "sda9"
        )
      end
    end

    context "when there are NFS mounts" do
      let(:scenario) { "nfs1.xml" }

      it "contains all NFS mounts, represented by their share string" do
        expect(items).to include("srv:/home/a", "srv2:/home/b")
      end
    end

    context "when there are bcache devices" do
      let(:scenario) { "bcache1.xml" }

      it "contains all bcache devices" do
        expect(items).to include("/dev/bcache0", "/dev/bcache1", "/dev/bcache2")
      end
    end

    context "when there are multidevice filesystems" do
      let(:scenario) { "btrfs2-devicegraph.xml" }
      let(:multidevice_filesystems) { current_graph.btrfs_filesystems.select(&:multidevice?) }

      it "contains all multidevice filesystems" do
        expected_items = multidevice_filesystems.map do |fs|
          "#{fs.type.to_human_string} #{fs.blk_device_basename}"
        end

        expect(items).to include(*expected_items)
      end
    end

    describe "caching" do
      let(:scenario) { "empty_hard_disk_15GiB" }
      let(:pager) { Y2Partitioner::Widgets::OverviewTreePager.new("hostname") }
      let(:nfs_page) { Y2Partitioner::Widgets::Pages::NfsMounts.new(pager) }

      # Device names from the table
      def rows
        widgets = Yast::CWM.widgets_in_contents([subject])
        table = find_table(widgets)
        row_names(table)
      end

      it "caches the table content between calls" do
        expect(remove_sort_keys(rows)).to eq ["/dev/sda"]
        Y2Storage::Filesystems::Nfs.create(current_graph, "new", "/device")
        # The new device is not included
        expect(remove_sort_keys(rows)).to eq ["/dev/sda"]
      end

      it "refreshes the cached content if the NFS page was visited" do
        expect(remove_sort_keys(rows)).to eq ["/dev/sda"]
        Y2Storage::Filesystems::Nfs.create(current_graph, "new", "/device")
        expect(remove_sort_keys(rows)).to eq ["/dev/sda"]
        # Leave the NFS page
        nfs_page.store
        # Now the device is there
        expect(remove_sort_keys(rows)).to eq ["/dev/sda", "new:/device"]
        Y2Storage::Filesystems::Nfs.create(current_graph, "another", "/device")
        # Still cached
        expect(remove_sort_keys(rows)).to eq ["/dev/sda", "new:/device"]
      end
    end
  end

  describe "#state_info" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }
    let(:table) { find_table(widgets) }
    let(:open) { { "id1" => true, "id2" => false } }

    it "returns a hash with the id of the devices table and its corresponding open items" do
      expect(table).to receive(:ui_open_items).and_return open
      expect(subject.state_info).to eq(table.widget_id => open)
    end
  end
end
