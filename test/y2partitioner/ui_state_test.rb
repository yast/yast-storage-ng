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
# find current contact information at www.suse.com.

require_relative "test_helper"
require "y2partitioner/ui_state"
require "y2partitioner/widgets/pages"

describe Y2Partitioner::UIState do
  subject(:ui_state) { described_class.instance }

  before do
    described_class.create_instance
    devicegraph_stub(scenario)
  end

  after do
    # UIState is a singleton class, so let's clean-up to not pollute other tests
    described_class.create_instance
  end

  let(:scenario) { "complex-lvm-encrypt.yml" }

  let(:device) { Y2Storage::BlkDevice.find_by_name(fake_devicegraph, device_name) }

  let(:disks) { fake_devicegraph.disks }

  let(:pager) { double("TreePager") }

  let(:system_page) { Y2Partitioner::Widgets::Pages::System.new("", pager) }
  let(:disk_page) { Y2Partitioner::Widgets::Pages::Disk.new(device.disk, pager) }
  let(:disks_page) { Y2Partitioner::Widgets::Pages::Disks.new(disks, pager) }
  let(:md_raids_page) { Y2Partitioner::Widgets::Pages::MdRaids.new(pager) }
  let(:lvm_page) { Y2Partitioner::Widgets::Pages::Lvm.new(pager) }
  let(:bcaches_page) { Y2Partitioner::Widgets::Pages::Bcaches.new(pager) }
  let(:btrfs_filesystems_page) { Y2Partitioner::Widgets::Pages::BtrfsFilesystems.new([], pager) }

  describe ".new" do
    it "cannot be used directly" do
      expect { described_class.new }.to raise_error(/private method/)
    end
  end

  describe ".instance" do
    it "returns the singleton object in subsequent calls" do
      initial = described_class.create_instance
      second = described_class.instance
      # Note using equal to ensure is actually the same object (same object_id)
      expect(second).to equal initial
      expect(described_class.instance).to equal initial
    end
  end

  describe ".create_instance" do
    it "returns a new singleton UIState object" do
      initial = described_class.instance
      result = described_class.create_instance
      expect(result).to be_a described_class
      expect(result).to_not equal initial
    end
  end

  describe "#find_page" do
    let(:pages) do
      [system_page, disks_page, md_raids_page, lvm_page, bcaches_page, btrfs_filesystems_page]
    end
    let(:pages_ids) { pages.map(&:id) }

    context "if the user has still not visited any page" do
      before { described_class.create_instance }

      it "returns nil" do
        expect(ui_state.find_page(pages_ids)).to be_nil
      end
    end

    context "when the user has opened a disk page" do
      let(:device_name) { "/dev/sdb" }
      let(:another_disk) { Y2Storage::Disk.find_by_name(fake_devicegraph, "/dev/sda") }

      let(:page) { Y2Partitioner::Widgets::Pages::Disk.new(device, pager) }
      let(:another_disk_page) { Y2Partitioner::Widgets::Pages::Disk.new(another_disk, pager) }

      before { ui_state.select_page(page.tree_path) }

      context "if the disk is still there after redrawing" do
        before { pages.push page, another_disk_page }

        it "selects the correct disk page" do
          expect(ui_state.find_page(pages_ids)).to eq page.id
        end
      end

      context "if the disk is not longer there after redrawing" do
        before { pages << another_disk_page }

        it "returns nil" do
          expect(ui_state.find_page(pages_ids)).to be_nil
        end
      end
    end

    context "when the user has opened an MD RAID page" do
      let(:scenario) { "md_raid.yml" }
      let(:device_name) { "/dev/md/md0" }
      let(:device) { Y2Storage::Md.find_by_name(fake_devicegraph, device_name) }

      let(:page) { Y2Partitioner::Widgets::Pages::MdRaid.new(device, pager) }

      before do
        ui_state.select_page(page.tree_path)
      end

      context "if the RAID is still there after redrawing" do
        before { pages << page }

        it "selects the RAID page" do
          expect(ui_state.find_page(pages_ids)).to eq page.id
        end
      end

      context "if the RAID is not longer there after redrawing" do
        it "selects the general MD RAIDs page" do
          expect(ui_state.find_page(pages_ids)).to eq md_raids_page.id
        end
      end
    end

    context "when the user has opened a VG page" do
      let(:device) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }
      let(:another_vg) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg1") }

      let(:page) { Y2Partitioner::Widgets::Pages::LvmVg.new(device, pager) }
      let(:another_vg_page) { Y2Partitioner::Widgets::Pages::LvmVg.new(another_vg, pager) }

      before { ui_state.select_page(page.tree_path) }

      context "if the VG is still there after redrawing" do
        before { pages.push page, another_vg_page }

        it "selects the correct VG page" do
          expect(ui_state.find_page(pages_ids)).to eq page.id
        end
      end

      context "if the VG is not longer there after redrawing" do
        before { pages << another_vg_page }

        it "selects the general LVM page" do
          expect(ui_state.find_page(pages_ids)).to eq lvm_page.id
        end
      end
    end

    context "when the user has opened a bcache page" do
      let(:scenario) { "bcache1.xml" }
      let(:device) { fake_devicegraph.find_by_name("/dev/bcache0") }
      let(:another_bcache) { fake_devicegraph.find_by_name("/dev/bcache1") }

      let(:page) { Y2Partitioner::Widgets::Pages::Bcache.new(device, pager) }
      let(:another_bcache_page) { Y2Partitioner::Widgets::Pages::Bcache.new(another_bcache, pager) }

      before { ui_state.select_page(page.tree_path) }

      context "if the bcache is still there after redrawing" do
        before { pages.push page, another_bcache_page }

        it "selects the correct bcache page" do
          expect(ui_state.find_page(pages_ids)).to eq page.id
        end
      end

      context "if the bcache is not longer there after redrawing" do
        before { pages << another_bcache_page }

        it "selects the general bcache page" do
          expect(ui_state.find_page(pages_ids)).to eq bcaches_page.id
        end
      end
    end

    context "when the user has opened a btrfs page" do
      let(:scenario) { "mixed_disks_btrfs" }
      let(:device) { fake_devicegraph.find_by_name("/dev/sda2").filesystem }
      let(:another_btrfs) { fake_devicegraph.find_by_name("/dev/sdb2").filesystem }

      let(:page) { Y2Partitioner::Widgets::Pages::Btrfs.new(device, pager) }
      let(:another_btrfs_page) { Y2Partitioner::Widgets::Pages::Btrfs.new(another_btrfs, pager) }

      before { ui_state.select_page(page.tree_path) }

      context "if the filesystem is still there after redrawing" do
        before { pages.push page, another_btrfs_page }

        it "selects the correct btrfs page" do
          expect(ui_state.find_page(pages_ids)).to eq page.id
        end
      end

      context "if the filesystem is not longer there after redrawing" do
        before { pages << another_btrfs_page }

        it "selects the general btrfs page" do
          expect(ui_state.find_page(pages_ids)).to eq btrfs_filesystems_page.id
        end
      end
    end
  end

  describe "#active_tab" do
    let(:vg) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }

    let(:vg_page) { Y2Partitioner::Widgets::Pages::LvmVg.new(vg, pager) }
    let(:vg_tab) { Y2Partitioner::Widgets::Pages::LvmVgTab.new(vg) }
    let(:pvs_tab) { Y2Partitioner::Widgets::Pages::LvmPvTab.new(vg, pager) }

    let(:tabs) { [vg_tab, pvs_tab] }

    before do
      ui_state.select_page(vg_page.tree_path)
    end

    context "if the user has still not clicked in any tab" do
      before { described_class.create_instance }

      it "returns nil" do
        expect(ui_state.active_tab).to be_nil
      end
    end

    context "when the user has switched to a tab in the current page" do
      before { ui_state.switch_to_tab(pvs_tab.label) }

      it "selects the corresponding page" do
        expect(ui_state.active_tab).to eq pvs_tab.label
      end

      context "but then moves to a different page" do
        before do
          ui_state.switch_to_tab(pvs_tab.label)
          ui_state.select_page(system_page.tree_path)
        end

        it "returns nil even if there is another tab with the same label" do
          expect(ui_state.active_tab).to be_nil
        end

        context "and comes back to the previous page" do
          before do
            ui_state.select_page(vg_page.tree_path)
          end

          it "returns nil" do
            expect(ui_state.active_tab).to be_nil
          end
        end
      end
    end
  end

  describe "#row_id" do
    let(:device_name) { "/dev/sda2" }

    let(:overview_tab) { double("Tab", label: "Overview") }
    let(:partitions_tab) { double("Tab", label: "Partitions") }

    before do
      described_class.create_instance
      ui_state.select_page(disk_page.tree_path)
      ui_state.switch_to_tab(partitions_tab)
    end

    context "if the user has still not selected any row" do
      before { described_class.create_instance }

      it "returns nil" do
        expect(ui_state.row_id).to be_nil
      end
    end

    context "if the user had selected a row in the current page and tab" do
      context "selecting the row by device" do
        before { ui_state.select_row(device.sid) }

        it "returns the sid of the device" do
          expect(ui_state.row_id).to eq device.sid
        end
      end

      context "selecting the row by sid" do
        before { ui_state.select_row(device.sid) }

        it "returns the sid of the device" do
          expect(ui_state.row_id).to eq device.sid
        end
      end
    end

    context "if the user had selected a row but then moved to a different tab" do
      before do
        ui_state.select_row(device.sid)
        ui_state.switch_to_tab(overview_tab)
      end

      it "returns nil" do
        expect(ui_state.row_id).to be_nil
      end

      context "and comes back to the previous tab" do
        before do
          ui_state.switch_to_tab(partitions_tab)
        end

        it "returns the last selected device row sid in this tab" do
          expect(ui_state.row_id).to eq(device.sid)
        end
      end
    end

    context "if the user had selected a row but then moved to a different page" do
      before do
        ui_state.select_row(device.sid)
        ui_state.select_page(system_page.tree_path)
      end

      it "returns nil" do
        expect(ui_state.row_id).to be_nil
      end

      context "and comes back to the previous page" do
        before do
          ui_state.select_page(disk_page.tree_path)
        end

        context "and to the same tab" do
          before do
            ui_state.switch_to_tab(partitions_tab)
          end

          it "returns the sid of last selected device in the page" do
            expect(ui_state.row_id).to eq(device.sid)
          end
        end

        context "but to a different tab" do
          before do
            ui_state.switch_to_tab(overview_tab)
          end

          it "returns nil" do
            expect(ui_state.row_id).to be_nil
          end
        end
      end
    end
  end

  describe "#open_items" do
    context "if the open items has not been saved" do
      before { described_class.create_instance }

      it "returns and empty hash" do
        expect(ui_state.open_items).to eq({})
      end
    end

    context "after calling #save_open_items" do
      before do
        # The first call returns {a: true, b: false} and the second returns {b: true}
        allow(pager).to receive(:open_items)
          .and_return({ a: true, b: false }, b: true)

        ui_state.overview_tree_pager = pager
        ui_state.save_open_items
      end

      it "returns the items that were expanded when #save_open_items was called" do
        expect(ui_state.open_items).to eq(a: true, b: false)
      end

      # To ensure this does not interfere with other tests
      after { ui_state.overview_tree_pager = nil }
    end
  end

  describe "#prune" do
    let(:device_name) { "/dev/sda" }
    let(:vg) { Y2Storage::LvmVg.find_by_vg_name(fake_devicegraph, "vg0") }

    let(:disks_page) { Y2Partitioner::Widgets::Pages::Disks.new(disks, pager) }
    let(:sda_page) { Y2Partitioner::Widgets::Pages::Disk.new(device, pager) }
    let(:lvm_page) { Y2Partitioner::Widgets::Pages::Lvm.new(pager) }
    let(:vg_page) { Y2Partitioner::Widgets::Pages::LvmVg.new(vg, pager) }

    let(:initial_pages) { [disks_page, sda_page, lvm_page, vg_page] }
    let(:final_pages) { [lvm_page, vg_page] }

    before do
      # generates statuses for all pages by selecting them
      initial_pages.each { |page| ui_state.select_page(page.tree_path) }
    end

    context "when keep: parameter is not given" do
      it "discards all statuses" do
        expect(ui_state.statuses).to_not be_empty

        ui_state.prune

        expect(ui_state.statuses).to be_empty
      end
    end

    context "when keep: parameter is given" do
      it "discards statuses which page_id is not present on it" do
        expect(ui_state.statuses.map(&:page_id)).to eq(initial_pages.map(&:id))

        ui_state.prune(keep: final_pages.map(&:id))

        expect(ui_state.statuses.map(&:page_id)).to eq(final_pages.map(&:id))
      end
    end
  end

  describe "#extra" do
    context "if the user has still not visited any page" do
      before { described_class.create_instance }

      it "returns nil" do
        expect(ui_state.extra).to eq nil
      end
    end

    context "if some information has been saved for a given page" do
      let(:info) { { "table" => "disks info" } }

      before do
        ui_state.select_page(disks_page.tree_path)
        ui_state.extra = info
      end

      it "returns that information while the user is still on that page" do
        expect(ui_state.extra).to eq info
      end

      it "does not longer return the information if the user moves to another page" do
        expect(ui_state.extra).to eq info
        ui_state.select_page(system_page.tree_path)
        expect(ui_state.extra).to_not eq info
      end

      it "returns the information if the user returns later to the page" do
        ui_state.select_page(system_page.tree_path)
        expect(ui_state.extra).to_not eq info
        ui_state.select_page(disks_page.tree_path)
        expect(ui_state.extra).to eq info
      end
    end

    context "if some information has been saved for a given tab" do
      let(:info) { { "table" => "Used devices info" } }
      let(:device_name) { "/dev/sda2" }
      let(:devices_tab) { double("Tab", label: "Used Devices") }

      before do
        ui_state.select_page(disk_page.tree_path)
        ui_state.switch_to_tab(devices_tab)
        ui_state.extra = info
      end

      it "returns that information while the user is still on that tab" do
        expect(ui_state.extra).to eq info
      end

      it "does not longer return the information if the user moves to another tab" do
        expect(ui_state.extra).to eq info
        ui_state.switch_to_tab(nil)
        expect(ui_state.extra).to_not eq info
      end

      it "returns the information if the user returns to the tab" do
        ui_state.switch_to_tab(nil)
        expect(ui_state.extra).to_not eq info
        ui_state.switch_to_tab(devices_tab)
        expect(ui_state.extra).to eq info
      end
    end
  end

  describe "#save_extra_info" do
    before do
      ui_state.overview_tree_pager = pager
      allow(pager).to receive(:current_page).and_return(system_page)
      ui_state.select_page(system_page.tree_path)
    end

    it "stores in #extra the state of the current page" do
      expect(system_page).to receive(:state_info).and_return("system" => "state")
      ui_state.save_extra_info
      expect(ui_state.extra).to eq("system" => "state")
    end
  end
end
