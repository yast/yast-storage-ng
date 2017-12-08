#!/usr/bin/env rspec
# encoding: utf-8

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
# find current contact information at www.suse.com

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/device_graphs"
require "y2partitioner/widgets/overview"

describe Y2Partitioner::Widgets::OverviewTreePager do
  before do
    devicegraph_stub(scenario)
    subject.init
  end

  subject { described_class.new("hostname") }

  let(:scenario) { "lvm-two-vgs.yml" }

  include_examples "CWM::Pager"

  describe "#device_page" do
    let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

    let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

    context "when there is a page associated to the requested device" do
      let(:device) { vg }

      it "returns the page" do
        page = subject.device_page(device)
        expect(page).to be_a(CWM::Page)
        expect(page.device).to eq(device)
      end
    end

    context "when there is not a page associated to the requested device" do
      let(:device) { vg.lvm_pvs.first }

      it "returns nil" do
        page = subject.device_page(device)
        expect(page).to be_nil
      end
    end
  end

  describe "#contents" do
    let(:scenario) { "empty-dasd-and-multipath.xml" }

    let(:widgets) { Yast::CWM.widgets_in_contents([subject]) }

    let(:overview_tree) { widgets.find { |w| w.is_a?(Y2Partitioner::Widgets::OverviewTree) } }

    let(:disks_pager) do
      system_pager = overview_tree.items.find { |i| i.page.is_a?(Y2Partitioner::Widgets::Pages::System) }
      system_pager.children.values.find { |i| i.page.is_a?(Y2Partitioner::Widgets::Pages::Disks) }
    end

    let(:disks_pages) { disks_pager.pages - [disks_pager.page] }

    it "has a OverviewTree widget" do
      expect(overview_tree).to_not be_nil
    end

    it "has a pager for the disk devices" do
      expect(disks_pager).to_not be_nil
    end

    context "when there are disk, dasd or multipath devices" do
      let(:scenario) { "empty-dasd-and-multipath.xml" }

      let(:md0) { "/dev/mapper/36005076305ffc73a00000000000013b4" }

      let(:md3) { "/dev/mapper/36005076305ffc73a00000000000013b5" }

      let(:dasd) { "/dev/dasdb" }

      let(:sde) { "/dev/sde" }

      it "disks pager has a page for each dasd device" do
        dasd_page = disks_pages.find { |p| p.device.name == dasd }
        expect(dasd_page).to_not be_nil
      end

      it "disks pager has a page for each multipath device" do
        md0_page = disks_pages.find { |p| p.device.name == md0 }
        expect(md0_page).to_not be_nil

        md3_page = disks_pages.find { |p| p.device.name == md3 }
        expect(md3_page).to_not be_nil
      end

      it "disks pager has a page for each disk device" do
        sde_page = disks_pages.find { |p| p.device.name == sde }
        expect(sde_page).to_not be_nil
      end

      it "disks pager has not a page for disks belonging to a multipath" do
        sda_page = disks_pages.find { |p| p.device.name == "/dev/sda" }
        expect(sda_page).to be_nil
      end
    end

    context "when there are BIOS RAIDs" do
      let(:scenario) { "md-imsm1-devicegraph.xml" }

      let(:mda) { "/dev/md/a" }

      let(:mdb) { "/dev/md/b" }

      let(:sda) { "/dev/sda" }

      it "disks pager has a page for each BIOS RAID device" do
        mda_page = disks_pages.find { |p| p.device.name == mda }
        expect(mda_page).to_not be_nil

        mdb_page = disks_pages.find { |p| p.device.name == mdb }
        expect(mdb_page).to_not be_nil
      end

      it "disks pager has a page for each disk device" do
        sda_page = disks_pages.find { |p| p.device.name == sda }
        expect(sda_page).to_not be_nil
      end

      it "disks pager has not a page for disks belonging to a BIOS RAID" do
        sdb_page = disks_pages.find { |p| p.device.name == "/dev/sdb" }
        expect(sdb_page).to be_nil

        sdc_page = disks_pages.find { |p| p.device.name == "/dev/sdc" }
        expect(sdc_page).to be_nil

        sdd_page = disks_pages.find { |p| p.device.name == "/dev/sdd" }
        expect(sdd_page).to be_nil
      end
    end

    context "when there are volume groups" do
      let(:scenario) { "lvm-two-vgs.yml" }

      it "disk pager has not vg pages" do
        vg_pages = disks_pages.select { |p| p.is_a?(Y2Partitioner::Widgets::Pages::LvmVg) }
        expect(vg_pages).to be_empty
      end
    end

    context "when there are Software RAIDs" do
      let(:scenario) { "md_raid.xml" }

      it "disk pager has not Software RAID pages" do
        md_pages = disks_pages.select { |p| p.is_a?(Y2Partitioner::Widgets::Pages::MdRaid) }
        expect(md_pages).to be_empty
      end
    end
  end
end
