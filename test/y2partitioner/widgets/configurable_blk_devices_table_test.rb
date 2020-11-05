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

require_relative "../test_helper"

require "cwm/rspec"
require "y2partitioner/widgets/device_table_entry"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/widgets/overview"

describe Y2Partitioner::Widgets::ConfigurableBlkDevicesTable do
  before do
    devicegraph_stub(scenario)
  end

  let(:scenario) { "mixed_disks_btrfs.yml" }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  subject { described_class.new(entries, pager) }

  let(:devices) { device_graph.disks }
  let(:entries) do
    devices.map { |dev| Y2Partitioner::Widgets::DeviceTableEntry.new_with_children(dev) }
  end

  let(:pager) { instance_double(Y2Partitioner::Widgets::OverviewTreePager) }
  let(:buttons_set) { instance_double(Y2Partitioner::Widgets::DeviceButtonsSet) }

  # FIXME: default tests check that all column headers are strings, but they also can be a Yast::Term
  # include_examples "CWM::Table"

  describe "#header" do
    it "returns array" do
      expect(subject.header).to be_a(::Array)
    end
  end

  describe "#items" do
    let(:devices) { device_graph.partitions }

    it "returns array of CWM::TableItem objects" do
      expect(subject.items).to be_a(::Array)
      expect(subject.items.first).to be_a(CWM::TableItem)
    end

    it "adds asterisk to mount point when not mounted" do
      allow_any_instance_of(Y2Storage::MountPoint).to receive(:active?).and_return(false)

      items = table_values(subject)
      expect(items.any? { |i| i.any? { |inner| inner =~ / */ } }).to(
        eq(true), "Missing items with asterisk: #{items.inspect}"
      )
    end
  end

  describe "#init" do
    before do
      allow(Yast::UI).to receive(:QueryWidget).with(anything, :SelectedItems).and_return []
    end

    context "when table does not contain any device" do
      let(:devices) { [] }

      it "does nothing" do
        expect(subject).to_not receive(:value=)

        subject.init
      end
    end

    context "when the table contains devices" do
      before do
        allow(Y2Partitioner::UIState.instance).to receive(:row_id).and_return(row_id)
      end

      let(:device) { devices.first }
      let(:selected_row) { subject.send(:entry, device.sid).row_id }

      shared_examples "selects the first device in the table" do
        it "selects the first device in the table" do
          expect(subject).to receive(:value=).with(selected_row)

          subject.init
        end
      end

      context "and UIState does not return an sid" do
        let(:row_id) { nil }

        include_examples "selects the first device in the table"
      end

      context "and UIState returns an sid for a device that is not in the table" do
        let(:row_id) { "999999999" }

        include_examples "selects the first device in the table"
      end

      context "and UIState returns an sid of a device in table" do
        let(:device) { devices.first.partitions.last }
        let(:row_id) { device.sid }

        it "sets value to row with the device" do
          expect(subject).to receive(:value=).with(selected_row)
          subject.init
        end

        context "if the table is associated to a buttons set" do
          subject { described_class.new(entries, pager, buttons_set) }

          it "initializes the buttons set according to the device" do
            expect(subject).to receive(:selected_device).and_return(device)
            expect(buttons_set).to receive(:device=).with device
            subject.init
          end
        end
      end

      context "and UIState returns the sid of the btrfs on one device of the table" do
        let(:device) { device_graph.find_by_name("/dev/sda2").filesystem }
        let(:selected_dev) { device.blk_devices.first }
        let(:row_id) { device.sid }
        let(:selected_row) { subject.send(:entry, selected_dev.sid).row_id }

        it "sets value to the row of the block device" do
          expect(subject).to receive(:value=).with(selected_row)
          subject.init
        end

        context "if the table is associated to a buttons set" do
          subject { described_class.new(entries, pager, buttons_set) }

          it "initializes the buttons set pointing to the block device" do
            expect(subject).to receive(:selected_device).and_return(selected_dev)
            expect(buttons_set).to receive(:device=).with selected_dev
            subject.init
          end
        end
      end
    end
  end

  describe "#handle" do
    subject { described_class.new(entries, pager, set) }

    before do
      allow(subject).to receive(:selected_device).and_return(device)
    end

    let(:device) { nil }
    let(:set) { nil }
    let(:page) { nil }

    context "when the event is Activated (double click)" do
      let(:event) { { "EventReason" => "Activated" } }

      before do
        allow(pager).to receive(:device_page?).and_return(device_page)
      end

      let(:device_page) { nil }

      context "when there is no selected device" do
        let(:device) { nil }

        it "returns nil" do
          expect(subject.handle(event)).to be_nil
        end
      end

      context "when there is a selected device" do
        let(:device) { device_graph.disks.first }

        context "and the current page is associated to a specific device" do
          let(:device_page) { true }

          let(:dialog) { instance_double(Y2Partitioner::Dialogs::DeviceDescription) }

          it "opens a dialog with the description of the selected device" do
            expect(Y2Partitioner::Dialogs::DeviceDescription).to receive(:new).with(device)
              .and_return(dialog)

            expect(dialog).to receive(:run)

            subject.handle(event)
          end
        end

        context "and the current page is not associated to a specific device" do
          let(:device_page) { false }

          before do
            allow(pager).to receive(:device_page).with(device).and_return(page)
            allow(pager).to receive(:handle)
          end

          context "and there is a page associated to the selected device" do
            let(:page) do
              instance_double(Y2Partitioner::Widgets::Pages::Disk, widget_id: "id", tree_path: ["disk"])
            end

            it "selects the device page" do
              expect(Y2Partitioner::UIState.instance).to receive(:select_page).with(page.tree_path)

              subject.handle(event)
            end

            it "selects the device row" do
              expect(Y2Partitioner::UIState.instance).to receive(:select_row).with(device.sid)

              subject.handle(event)
            end

            it "calls the pager handler with the proper event" do
              expect(pager).to receive(:handle).with("ID" => page.widget_id)

              subject.handle(event)
            end
          end

          context "and there is no page associated to the selected device" do
            let(:page) { nil }

            let(:device) { device_graph.partitions.first }

            let(:parent) { device.partitionable }

            let(:parent_page) do
              instance_double(Y2Partitioner::Widgets::Pages::Disk,
                widget_id: "parent_id", tree_path: ["disk", "parent"])
            end

            before do
              allow(pager).to receive(:device_page).with(parent).and_return(parent_page)
            end

            it "selects the device page associated to the parent entry" do
              expect(Y2Partitioner::UIState.instance)
                .to receive(:select_page).with(parent_page.tree_path)

              subject.handle(event)
            end

            it "selects the device row" do
              expect(Y2Partitioner::UIState.instance).to receive(:select_row).with(device.sid)

              subject.handle(event)
            end

            it "calls the pager handler with the proper event" do
              expect(pager).to receive(:handle).with("ID" => parent_page.widget_id)

              subject.handle(event)
            end
          end
        end
      end
    end

    context "when the event is SelectionChanged (single click)" do
      let(:event) { { "EventReason" => "SelectionChanged" } }

      context "when there is a buttons set associated to the table" do
        let(:set) { buttons_set }

        before do
          allow(buttons_set).to receive(:device=).with(device)
        end

        context "and there is no selected device" do
          let(:device) { nil }

          it "does not try to notify the change to the UIState" do
            expect(Y2Partitioner::UIState.instance).to_not receive(:select_row)
            subject.handle(event)
          end

          it "does not try to update the buttons set" do
            expect(buttons_set).to_not receive(:device=)
            subject.handle(event)
          end

          it "returns nil" do
            expect(subject.handle(event)).to be_nil
          end
        end

        context "and some device is selected" do
          let(:device) { Y2Storage::Disk.all(device_graph).first }

          it "notifies the selected device to the UIState" do
            expect(Y2Partitioner::UIState.instance).to receive(:select_row).with(device.sid)
            subject.handle(event)
          end

          it "updates the buttons set according to the device" do
            expect(buttons_set).to receive(:device=).with(device)
            subject.handle(event)
          end

          it "returns nil" do
            allow(buttons_set).to receive(:device=)
            expect(subject.handle(event)).to be_nil
          end
        end
      end

      context "when there is no buttons set associated to the table" do
        context "and there is no selected device" do
          let(:device) { nil }

          it "does not try to notify the change to the UIState" do
            expect(Y2Partitioner::UIState.instance).to_not receive(:select_row)
            subject.handle(event)
          end

          it "does not try to update the buttons set" do
            expect(buttons_set).to_not receive(:device=)
            subject.handle(event)
          end

          it "returns nil" do
            expect(subject.handle(event)).to be_nil
          end
        end

        context "and some device is selected" do
          let(:device) { Y2Storage::Disk.all(device_graph).first }

          it "notifies the selected device to the UIState" do
            expect(Y2Partitioner::UIState.instance).to receive(:select_row).with(device.sid)
            subject.handle(event)
          end

          it "does not try to update the buttons set" do
            expect(buttons_set).to_not receive(:device=)
            subject.handle(event)
          end

          it "returns nil" do
            expect(subject.handle(event)).to be_nil
          end
        end
      end
    end
  end

  describe "#selected_device" do
    context "when the table is empty" do
      before do
        allow(subject).to receive(:items).and_return([])
      end

      it "returns nil" do
        expect(subject.selected_device).to be_nil
      end
    end

    context "when the table is not empty" do
      context "and there is no selected row" do
        before do
          allow(subject).to receive(:value).and_return(nil)
        end

        it "returns nil" do
          expect(subject.selected_device).to be_nil
        end
      end

      context "and a row is selected" do
        before do
          allow(subject).to receive(:value).and_return("table:partition:#{selected_device.sid}")
        end

        let(:selected_device) do
          Y2Storage::BlkDevice.find_by_name(device_graph, selected_device_name)
        end

        let(:selected_device_name) { "/dev/sda2" }

        it "returns the selected device" do
          device = subject.selected_device

          expect(device).to eq(selected_device)
        end
      end
    end
  end

  describe "#ui_open_items" do
    # sdb contains 3 primary partitions, one extended and 3 logical ones
    # including three logical ones
    let(:sdb) { device_graph.find_by_name("/dev/sdb") }
    let(:sdb2) { device_graph.find_by_name("/dev/sdb2") }
    let(:sdb4) { device_graph.find_by_name("/dev/sdb4") }
    let(:devices) { [sdb] }

    before do
      allow(Yast::UI).to receive(:QueryWidget).with(anything, :OpenItems)
        .and_return(open_items)
    end

    let(:open_items) do
      { "table:device:#{sdb4.sid}"=>"ID" }
    end

    def btrfs_subvolumes(device)
      device.filesystem.btrfs_subvolumes.reject { |s| s.top_level? || s.default_btrfs_subvolume? }
    end

    it "contains an entry for each item of the table" do
      devs = [sdb] + sdb.partitions + btrfs_subvolumes(sdb2)
      ids = devs.map { |dev| "table:device:#{dev.sid}" }
      expect(subject.ui_open_items.keys).to contain_exactly(*ids)
    end

    it "reports true for the open items and false for the rest" do
      values = [false] * 10 + [true]
      expect(subject.ui_open_items.values).to contain_exactly(*values)
      expect(subject.ui_open_items["table:device:#{sdb4.sid}"]).to eq true
    end
  end

  describe "#open_items" do
    let(:devices) { [sda] }

    let(:sda) { device_graph.find_by_name("/dev/sda") }
    let(:sda2) { device_graph.find_by_name("/dev/sda2") }

    before do
      subject.open_items = open_items
    end

    context "when #open_items has not been set" do
      let(:open_items) { nil }

      it "reports true for items with 10 children at most" do
        result = subject.open_items
        result.reject! { |k, _| k == "table:device:#{sda2.sid}" }

        expect(result.values).to all(eq(true))
      end

      it "reports false for items with more than 10 children" do
        result = subject.open_items

        expect(result["table:device:#{sda2.sid}"]).to eq(false)
      end
    end

    context "when #open_items has been set" do
      let(:open_items) { { "table:device:33" => true, "table::device::34" => false } }

      it "returns its current value" do
        expect(subject.open_items).to eq(open_items)
      end
    end
  end
end
