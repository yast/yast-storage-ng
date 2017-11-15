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
require "y2partitioner/dialogs/md"
require "y2partitioner/actions/controllers"

Yast.import "UI"

describe Y2Partitioner::Dialogs::Md do
  before { devicegraph_stub("lvm-two-vgs.yml") }

  let(:controller) do
    Y2Partitioner::Actions::Controllers::Md.new
  end

  subject { described_class.new(controller) }

  include_examples "CWM::Dialog"

  describe Y2Partitioner::Dialogs::Md::LevelChoice do
    let(:devices_selection) { double("DevicesSelection", refresh_sizes: nil) }

    subject(:widget) { described_class.new(controller, devices_selection) }

    before { allow(Yast::UI).to receive(:QueryWidget).and_return :raid0 }

    include_examples "CWM::CustomWidget"

    describe "#handle" do
      it "sets the level of the RAID and updates the sizes in the UI afterwards" do
        allow(Yast::UI).to receive(:QueryWidget).and_return :raid10
        expect(controller).to receive(:md_level=).with(Y2Storage::MdLevel::RAID10).ordered
        expect(devices_selection).to receive(:refresh_sizes).ordered

        widget.handle
      end
    end
  end

  describe Y2Partitioner::Dialogs::Md::NameEntry do
    include_examples "CWM::AbstractWidget"
  end

  describe Y2Partitioner::Dialogs::Md::DevicesSelection do
    def dev(name)
      Y2Storage::BlkDevice.find_by_name(current_graph, name)
    end

    def row_match?(row, regexp)
      row.any? { |column| column.match?(regexp) }
    end

    def rows_match?(rows, *args)
      args.all? do |arg|
        rows.any? { |row| row_match?(row, arg) }
      end
    end

    let(:controller) { Y2Partitioner::Actions::Controllers::Md.new }

    let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

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

      controller.add_device(dev("/dev/sda3"))
      controller.add_device(dev("/dev/sde3"))
    end

    include_examples "CWM::CustomWidget"

    context "right after initialization" do
      describe "#contents" do
        it "displays all the unselected devices in the corresponding table" do
          items = unselected_table.items
          expect(items.size).to eq 2
          expect(rows_match?(items, "^/dev/sda2$", "^/dev/sda4$")).to eq true
        end

        it "displays all the selected devices in the corresponding table and order" do
          items = selected_table.items
          expect(items.size).to eq 2
          expect(rows_match?(items, "^/dev/sda3$", "^/dev/sde3$")).to eq true
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

        it "includes all the devices in the MD array" do
          widget.handle(event)
          expect(controller.devices_in_md.map(&:name)).to contain_exactly(
            "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sde3"
          )
        end
      end

      describe "#contents" do
        before { widget.handle(event) }

        it "displays all the selected devices in the corresponding table" do
          items = selected_table.items
          expect(items.size).to eq 4
          names = ["/dev/sda2$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
          expect(rows_match?(items, *names)).to eq true
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
            expect(controller.devices_in_md.map(&:name)).to contain_exactly("/dev/sda3", "/dev/sde3")
            expect(controller.available_devices.map(&:name)).to contain_exactly("/dev/sda2", "/dev/sda4")
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table" do
            items = selected_table.items
            expect(items.size).to eq 2
            expect(rows_match?(items, "/dev/sda3$", "/dev/sde3$")).to eq true
          end

          it "displays all the available devices in the corresponding table" do
            items = unselected_table.items
            expect(items.size).to eq 2
            expect(rows_match?(items, "/dev/sda2$", "/dev/sda4$")).to eq true
          end
        end
      end

      context "if some items where selected in the 'unselected' table" do
        let(:selection) { ["unselected:device:#{dev("/dev/sda2").sid}"] }

        describe "#handle" do
          it "adds the devices to the MD RAID" do
            widget.handle(event)
            expect(controller.devices_in_md.map(&:name)).to contain_exactly(
              "/dev/sda2", "/dev/sda3", "/dev/sde3"
            )
          end

          it "causes the device to not be longer available" do
            widget.handle(event)
            expect(controller.available_devices.map(&:name)).to contain_exactly("/dev/sda4")
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table" do
            items = selected_table.items
            expect(items.size).to eq 3
            expect(rows_match?(items, "/dev/sda2$", "/dev/sda3$", "/dev/sde3$")).to eq true
          end

          it "displays all the available devices in the corresponding table" do
            items = unselected_table.items
            expect(items.size).to eq 1
            expect(rows_match?(items, "/dev/sda4$")).to eq true
          end
        end
      end
    end

    context "pushing the 'Remove All' button" do
      let(:event) { { "ID" => :remove_all } }

      describe "#handle" do
        it "removes all devices from the RAID" do
          widget.handle(event)
          expect(controller.devices_in_md).to be_empty
        end

        it "makes all devices available" do
          widget.handle(event)
          expect(controller.available_devices.map(&:name)).to contain_exactly(
            "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sde3"
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
          expect(items.size).to eq 4
          names = ["/dev/sda2$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
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
            expect(controller.devices_in_md.map(&:name)).to contain_exactly("/dev/sda3", "/dev/sde3")
            expect(controller.available_devices.map(&:name)).to contain_exactly("/dev/sda2", "/dev/sda4")
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table" do
            items = selected_table.items
            expect(items.size).to eq 2
            expect(rows_match?(items, "/dev/sda3$", "/dev/sde3$")).to eq true
          end

          it "displays all the available devices in the corresponding table" do
            items = unselected_table.items
            expect(items.size).to eq 2
            expect(rows_match?(items, "/dev/sda2$", "/dev/sda4$")).to eq true
          end
        end
      end

      context "if some items where selected in the 'selected' table" do
        let(:selection) { ["selected:device:#{dev("/dev/sda3").sid}"] }

        describe "#handle" do
          it "removes the devices from the MD RAID" do
            widget.handle(event)
            expect(controller.devices_in_md.map(&:name)).to contain_exactly("/dev/sde3")
          end

          it "makes the device available" do
            widget.handle(event)
            expect(controller.available_devices.map(&:name)).to contain_exactly(
              "/dev/sda2", "/dev/sda3", "/dev/sda4"
            )
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table" do
            items = selected_table.items
            expect(items.size).to eq 1
            expect(rows_match?(items, "/dev/sde3$")).to eq true
          end

          it "displays all the available devices in the corresponding table" do
            items = unselected_table.items
            expect(items.size).to eq 3
            expect(rows_match?(items, "/dev/sda2$", "/dev/sda3$", "/dev/sda4$")).to eq true
          end
        end
      end
    end

    describe "#validate" do
      context "if there are enough devices in the MD array" do
        it "shows no pop-up" do
          expect(Yast::Popup).to_not receive(:Error)
          widget.validate
        end

        it "returns true" do
          expect(widget.validate).to eq true
        end
      end

      context "if there are not enough devices in the MD array" do
        before { controller.remove_device(dev("/dev/sda3")) }

        it "shows an error pop-up" do
          expect(Yast::Popup).to receive(:Error)
          widget.validate
        end

        it "returns false" do
          allow(Yast::Popup).to receive(:Error)
          expect(widget.validate).to eq false
        end
      end
    end
  end
end
