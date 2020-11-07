#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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
require "y2partitioner/widgets/overview_tab"

describe Y2Partitioner::Widgets::OverviewTab do
  before { devicegraph_stub(scenario) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { current_graph.find_by_name(device_name) }
  let(:pager) { double("Pager") }

  subject { described_class.new(device, pager) }

  describe "#contents" do
    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }
    let(:table) { widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::ConfigurableBlkDevicesTable) } }
    let(:items) { column_values(table, 0) }

    # Device names for the children items of the given item
    def children_names(item)
      item.children.map { |child| remove_sort_key(child.values.first) }
    end

    RSpec.shared_examples "overview tab without partitions" do
      it "contains a graph bar" do
        bar = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DiskBarGraph) }
        expect(bar).to_not be_nil
      end

      it "shows a table containing only the device" do
        expect(table).to_not be_nil

        expect(items).to eq [device_name]
        expect(table.items.first.children).to be_empty
      end
    end

    RSpec.shared_examples "overview tab with partitions" do
      it "contains a graph bar" do
        bar = widgets.detect { |i| i.is_a?(Y2Partitioner::Widgets::DiskBarGraph) }
        expect(bar).to_not be_nil
      end

      it "shows a table with the device and its partitions as nested items" do
        expect(table).to_not be_nil

        part_names = device.partitions.map(&:basename)
        expect(items).to include(device_name, *part_names)

        expect(table.items.size).to eq 1
        item = table.items.first
        expect(children_names(item)).to contain_exactly(*part_names)
      end
    end

    context "for a disk" do
      let(:scenario) { "mixed_disks" }
      let(:device_name) { "/dev/sdc" }

      include_examples "CWM::Tab"

      context "when the disk contains no partitions" do
        include_examples "overview tab without partitions"
      end

      context "when the disk is partitioned" do
        let(:device_name) { "/dev/sda" }

        include_examples "overview tab with partitions"
      end

      context "when the disk contains logical partitions" do
        let(:device_name) { "/dev/sdb" }
        let(:primary) { ["sdb1", "sdb2", "sdb3"] }
        let(:extended) { "sdb4" }
        let(:logical) { ["sdb5", "sdb6", "sdb7"] }

        it "shows a table with the device and its partitions correctly nested" do
          part_names = primary + [extended] + logical
          expect(items).to contain_exactly(device_name, *part_names)

          expect(table.items.size).to eq 1

          first_item = table.items.first
          expect(children_names(first_item)).to contain_exactly(*primary, extended)

          ext_item = first_item.children.find do |item|
            remove_sort_key(item.values.first) == extended
          end
          expect(children_names(ext_item)).to contain_exactly(*logical)
        end
      end

      context "when the disk contains partitions formatted as Btrfs" do
        def btrfs_subvolumes(device)
          device.filesystem.btrfs_subvolumes.reject { |s| s.top_level? || s.default_btrfs_subvolume? }
        end

        context "and the Btrfs is not multidevice" do
          let(:scenario) { "mixed_disks_btrfs" }

          let(:device_name) { "/dev/sda" }

          it "shows a table with Btrfs subvolumes correctly nested" do
            first_item = table.items.first

            sda2_item = first_item.children.find do |item|
              remove_sort_key(item.values.first) == "sda2"
            end

            sda2 = current_graph.find_by_name("/dev/sda2")
            subvolumes = btrfs_subvolumes(sda2).map(&:path)

            expect(children_names(sda2_item)).to contain_exactly(*subvolumes)
          end
        end

        context "and the Btrfs is multidevice" do
          let(:scenario) { "btrfs-multidevice-over-partitions.xml" }

          let(:device_name) { "/dev/sda" }

          it "shows a table without the Btrfs subvolumes" do
            first_item = table.items.first

            sda2_item = first_item.children.find do |item|
              remove_sort_key(item.values.first) == "sda2"
            end

            expect(sda2_item.children).to be_empty
          end
        end
      end
    end

    context "for an MD RAID" do
      let(:scenario) { "md_raid" }
      let(:device_name) { "/dev/md/md0" }

      include_examples "CWM::Tab"

      context "when the RAID contains no partitions" do
        include_examples "overview tab without partitions"
      end

      context "when the RAID is partitioned" do
        let(:scenario) { "partitioned_md_raid.xml" }

        include_examples "overview tab with partitions"
      end
    end

    context "for a bcache device" do
      let(:scenario) { "bcache2.xml" }
      let(:device_name) { "/dev/bcache0" }

      include_examples "CWM::Tab"

      context "when the bcache device contains no partitions" do
        include_examples "overview tab without partitions"
      end

      context "when the bcache device is partitioned" do
        let(:device_name) { "/dev/bcache1" }

        include_examples "overview tab with partitions"
      end
    end
  end
end
