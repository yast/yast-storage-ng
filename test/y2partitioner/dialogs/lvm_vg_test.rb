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
# find current contact information at www.suse.com.

require_relative "../test_helper"

require "yast"
require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/lvm_vg"
require "y2partitioner/actions/controllers/lvm_vg"

describe Y2Partitioner::Dialogs::LvmVg do
  using Y2Storage::Refinements::SizeCasts

  before do
    devicegraph_stub("complex-lvm-encrypt.yml")
  end

  subject { described_class.new(controller) }

  let(:controller) { Y2Partitioner::Actions::Controllers::LvmVg.new }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  include_examples "CWM::Dialog"

  describe "#contents" do
    it "contains a widget for the vg name" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::LvmVg::NameWidget)
      end
      expect(widget).to_not be_nil
    end

    it "contains a widget for the vg extent size" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::LvmVg::ExtentSizeWidget)
      end
      expect(widget).to_not be_nil
    end

    it "contains a widget for the vg device" do
      widget = subject.contents.nested_find do |i|
        i.is_a?(Y2Partitioner::Dialogs::LvmVg::DevicesWidget)
      end
      expect(widget).to_not be_nil
    end
  end

  describe Y2Partitioner::Dialogs::LvmVg::NameWidget do
    subject { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"

    describe "#init" do
      before do
        controller.vg_name = "vg1"
      end

      it "sets its value with vg name stored in the controller" do
        expect(subject).to receive(:value=).with("vg1")
        subject.init
      end

      it "gets focus" do
        expect(Yast::UI).to receive(:SetFocus).with(Id(subject.widget_id))
        subject.init
      end
    end

    describe "#handle" do
      before do
        allow(subject).to receive(:value).and_return("vg1")
      end

      it "stores in the controller the given vg name" do
        subject.handle
        expect(controller.vg_name).to eq("vg1")
      end

      it "returns nil" do
        expect(subject.handle).to be_nil
      end
    end

    describe "#validate" do
      before do
        controller.vg_name = vg_name
      end

      let(:vg_name) { nil }

      it "gets focus" do
        expect(Yast::UI).to receive(:SetFocus).with(Id(subject.widget_id))
        subject.init
      end

      context "when the vg name is not given" do
        let(:vg_name) { "" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "when the vg name has invalid characters" do
        let(:vg_name) { "vg%" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "when a device exists with the given vg name" do
        let(:vg_name) { "sda" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "when the given vg name is valid" do
        let(:vg_name) { "vg100" }

        it "does not show an error popup" do
          expect(Yast::Popup).to_not receive(:Error)
          subject.validate
        end

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::LvmVg::ExtentSizeWidget do
    subject { described_class.new(controller) }

    include_examples "CWM::AbstractWidget"

    describe "#init" do
      before do
        controller.extent_size = "128 KiB"
      end

      it "sets its value with the extent size stored in the controller" do
        expect(subject).to receive(:value=).with("128 KiB")
        subject.init
      end
    end

    describe "#handle" do
      before do
        allow(subject).to receive(:value).and_return(value)
      end

      let(:value) { "1 MiB" }

      it "stores in the controller the given extent size" do
        expect(controller.extent_size).to_not eq(1.MiB)
        subject.handle
        expect(controller.extent_size).to eq(1.MiB)
      end

      it "returns nil" do
        expect(subject.handle).to be_nil
      end

      context "when no extent size is given" do
        let(:value) { "" }

        before do
          controller.extent_size = "1 MiB"
        end

        it "stores nil in the controller" do
          expect(controller.extent_size).to_not be_nil
          subject.handle
          expect(controller.extent_size).to be_nil
        end
      end

      context "when extent size with not valid format is given" do
        let(:value) { "4 bad units" }

        before do
          controller.extent_size = "1 MiB"
        end

        it "stores nil in the controller" do
          expect(controller.extent_size).to_not be_nil
          subject.handle
          expect(controller.extent_size).to be_nil
        end
      end
    end

    describe "#validate" do
      before do
        allow(controller).to receive(:invalid_extent_size?).and_return(!valid)
      end

      context "when the given extent size is not valid" do
        let(:valid) { false }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          subject.validate
        end

        it "returns false" do
          expect(subject.validate).to eq(false)
        end
      end

      context "when the given extent size is valid" do
        let(:valid) { true }

        it "does not show an error popup" do
          expect(Yast::Popup).to_not receive(:Error)
          subject.validate
        end

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end
    end
  end

  describe Y2Partitioner::Dialogs::LvmVg::DevicesWidget do
    def dev(name)
      Y2Storage::BlkDevice.find_by_name(current_graph, name)
    end

    def row_match?(row, regexp)
      row.any? { |column| column.respond_to?(:match?) && column.match?(regexp) }
    end

    def rows_match?(rows, *args)
      args.all? do |arg|
        rows.any? { |row| row_match?(row, arg) }
      end
    end

    subject(:widget) { described_class.new(controller) }

    let(:unselected_table) do
      widget.contents.nested_find { |i| i.is_a?(CWM::Table) && i.widget_id == "unselected" }
    end

    let(:selected_table) do
      widget.contents.nested_find { |i| i.is_a?(CWM::Table) && i.widget_id == "selected" }
    end

    before do
      # Ensure Yast::UI.Glyph and Yast::UI.GetDisplayInfo return something,
      # which is currently not guaranteed with the dummy UI used in the tests
      # (no ncurses or Qt).
      allow(Yast::UI).to receive(:Glyph).and_return ""
      allow(Yast::UI).to receive(:GetDisplayInfo).and_return("HasIconSupport" => false)

      devicegraph_stub("complex-lvm-encrypt.yml")

      controller.add_device(dev("/dev/sdc"))
      controller.add_device(dev("/dev/sda2"))
    end

    include_examples "CWM::CustomWidget"

    context "right after initialization" do
      describe "#contents" do
        it "displays all the unselected devices in the corresponding table" do
          items = unselected_table.items
          expect(items.size).to eq(4)
          names = ["^/dev/sdb$", "^/dev/sda3$", "^/dev/sda4$", "^/dev/sde3$"]
          expect(rows_match?(items, *names)).to eq(true)
        end

        it "displays all the selected devices in the corresponding table and order" do
          items = selected_table.items
          expect(items.size).to eq(2)
          expect(rows_match?(items, "^/dev/sdc$", "^/dev/sda2$")).to eq(true)
        end
      end
    end

    context "pushing the 'Add All' button" do
      let(:event) { { "ID" => :add_all } }

      describe "#handle" do
        it "leaves no available devices" do
          widget.handle(event)
          expect(controller.available_devices).to be_empty
        end

        it "includes all the devices in the vg" do
          widget.handle(event)
          expect(controller.devices_in_vg.map(&:name)).to contain_exactly(
            "/dev/sdb", "/dev/sdc", "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sde3"
          )
        end
      end

      describe "#contents" do
        before { widget.handle(event) }

        it "displays all the selected devices in the corresponding table" do
          items = selected_table.items
          expect(items.size).to eq(6)
          names = ["/dev/sdb$", "/dev/sdc$", "/dev/sda2$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
          expect(rows_match?(items, *names)).to eq(true)
        end

        it "displays no unselected devices" do
          items = unselected_table.items
          expect(items).to be_empty
        end
      end
    end

    context "pushing the 'Add' button" do
      let(:event) { { "ID" => :add } }

      before do
        allow(unselected_table).to receive(:value).and_return selection
      end

      context "if there were no selected item in the 'unselected' table" do
        let(:selection) { [] }

        describe "#handle" do
          it "does not alter the controller lists (no changes)" do
            widget.handle(event)
            expect(controller.devices_in_vg.map(&:name))
              .to contain_exactly("/dev/sdc", "/dev/sda2")
            expect(controller.available_devices.map(&:name))
              .to contain_exactly("/dev/sdb", "/dev/sda3", "/dev/sda4", "/dev/sde3")
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table" do
            items = selected_table.items
            expect(items.size).to eq(2)
            names = ["/dev/sdc$", "/dev/sda2$"]
            expect(rows_match?(items, *names)).to eq(true)
          end

          it "displays all the available devices in the corresponding table" do
            items = unselected_table.items
            expect(items.size).to eq(4)
            names = ["/dev/sdb$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
            expect(rows_match?(items, *names)).to eq(true)
          end
        end
      end

      context "if some items where selected in the 'unselected' table" do
        let(:selection) { ["unselected:device:#{dev("/dev/sda3").sid}"] }

        describe "#handle" do
          it "adds the devices to the vg" do
            widget.handle(event)
            expect(controller.devices_in_vg.map(&:name)).to contain_exactly(
              "/dev/sdc", "/dev/sda2", "/dev/sda3"
            )
          end

          it "causes the device to not be longer available" do
            widget.handle(event)
            expect(controller.available_devices.map(&:name)).to_not include("/dev/sda3")
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table" do
            items = selected_table.items
            expect(items.size).to eq(3)
            names = ["/dev/sdc$", "/dev/sda2$", "/dev/sda3$"]
            expect(rows_match?(items, *names)).to eq(true)
          end

          it "displays all the available devices in the corresponding table" do
            items = unselected_table.items
            expect(items.size).to eq(3)
            names = ["/dev/sdb$", "/dev/sda4$", "/dev/sde3$"]
            expect(rows_match?(items, *names)).to eq(true)
          end
        end
      end
    end

    context "pushing the 'Remove All' button" do
      let(:event) { { "ID" => :remove_all } }

      describe "#handle" do
        it "removes all devices from the vg" do
          widget.handle(event)
          expect(controller.devices_in_vg).to be_empty
        end

        it "makes all devices available" do
          widget.handle(event)
          expect(controller.available_devices.map(&:name)).to contain_exactly(
            "/dev/sdb", "/dev/sdc", "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sde3"
          )
        end
      end

      describe "#contents" do
        before { widget.handle(event) }

        it "displays no selected devices" do
          items = selected_table.items
          expect(items).to be_empty
        end

        it "displays all the available devices in the corresponding table" do
          items = unselected_table.items
          expect(items.size).to eq 6
          names = ["/dev/sdb$", "/dev/sdc$", "/dev/sda2$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
          expect(rows_match?(items, *names)).to eq true
        end
      end
    end

    context "pushing the 'Remove' button" do
      let(:event) { { "ID" => :remove } }

      before do
        allow(selected_table).to receive(:value).and_return selection
      end

      context "if there were no selected item in the 'selected' table" do
        let(:selection) { [] }

        describe "#handle" do
          it "does not alter the controller lists (no changes)" do
            widget.handle(event)
            expect(controller.devices_in_vg.map(&:name))
              .to contain_exactly("/dev/sdc", "/dev/sda2")
            expect(controller.available_devices.map(&:name))
              .to contain_exactly("/dev/sdb", "/dev/sda3", "/dev/sda4", "/dev/sde3")
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table" do
            items = selected_table.items
            expect(items.size).to eq(2)
            names = ["/dev/sdc$", "/dev/sda2$"]
            expect(rows_match?(items, *names)).to eq(true)
          end

          it "displays all the available devices in the corresponding table" do
            items = unselected_table.items
            expect(items.size).to eq(4)
            names = ["/dev/sdb$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
            expect(rows_match?(items, *names)).to eq(true)
          end
        end
      end

      context "if some items where selected in the 'selected' table" do
        let(:selection) { ["selected:device:#{dev("/dev/sda2").sid}"] }

        describe "#handle" do
          it "removes the devices from the vg" do
            widget.handle(event)
            expect(controller.devices_in_vg.map(&:name)).to contain_exactly("/dev/sdc")
          end

          it "makes the device available" do
            widget.handle(event)
            expect(controller.available_devices.map(&:name)).to contain_exactly(
              "/dev/sdb", "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sde3"
            )
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table" do
            items = selected_table.items
            expect(items.size).to eq(1)
            expect(rows_match?(items, "/dev/sdc$")).to eq true
          end

          it "displays all the available devices in the corresponding table" do
            items = unselected_table.items
            expect(items.size).to eq(5)
            names = ["/dev/sdb$", "/dev/sda2$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
            expect(rows_match?(items, *names)).to eq true
          end
        end
      end
    end

    describe "#validate" do
      context "if there are selected devices" do
        it "does not show an error popup" do
          expect(Yast::Popup).to_not receive(:Error)
          widget.validate
        end

        it "returns true" do
          expect(widget.validate).to eq(true)
        end
      end

      context "if there are not selected devices" do
        before do
          controller.remove_device(dev("/dev/sdc"))
          controller.remove_device(dev("/dev/sda2"))
        end

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end

        it "returns false" do
          allow(Yast::Popup).to receive(:Error)
          expect(widget.validate).to eq(false)
        end
      end
    end
  end
end
