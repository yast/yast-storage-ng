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
require "y2partitioner/widgets/main_menu_bar"

describe Y2Partitioner::Widgets::MainMenuBar do
  before do
    devicegraph_stub("complex-lvm-encrypt")
  end

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { device_graph.disks.first }

  subject(:widget) { described_class.new }

  include_examples "CWM::CustomWidget"

  # Just to shorten
  let(:system) { Y2Partitioner::Widgets::Menus::System }
  let(:add) { Y2Partitioner::Widgets::Menus::Add }
  let(:modify) { Y2Partitioner::Widgets::Menus::Modify }
  let(:view) { Y2Partitioner::Widgets::Menus::View }

  describe "#contents" do
    context "if no device or page has been selected yet" do
      it "contains no menus" do
        menus = widget.contents.params[1]
        expect(menus).to eq []
      end
    end

    context "if a page with no devices has been selected" do
      before { widget.select_page }

      it "contains menus for System, Add, Modify and View" do
        menus = widget.contents.params[1]
        expect(menus.map(&:value)).to all(eq :menu)
        titles = menus.map { |m| m.params[0] }
        expect(titles).to eq ["&System", "&Add", "&Device", "&View"]
      end
    end

    context "if a device has been selected" do
      before { widget.select_row(device.sid) }

      it "contains menus for System, Add, Modify and View" do
        menus = widget.contents.params[1]
        expect(menus.map(&:value)).to all(eq :menu)
        titles = menus.map { |m| m.params[0] }
        expect(titles).to eq ["&System", "&Add", "&Device", "&View"]
      end
    end
  end

  describe "#select_page" do
    it "initializes the Add and Modify menus with no device" do
      expect(add).to receive(:new).with(nil).and_call_original
      expect(modify).to receive(:new).with(nil).and_call_original
      widget.select_page
    end
  end

  describe "#select_row" do
    it "initializes the Add and Modify menus with the corresponding device" do
      expect(add).to receive(:new).with(device).and_call_original
      expect(modify).to receive(:new).with(device).and_call_original
      widget.select_row(device.sid)
    end
  end

  describe "#handle" do
    let(:system_menu) { system.new }
    let(:add_menu) { add.new(device) }
    let(:modify_menu) { modify.new(device) }
    let(:view_menu) { view.new }

    before do
      allow(system).to receive(:new).and_return system_menu
      allow(add).to receive(:new).and_return add_menu
      allow(modify).to receive(:new).and_return modify_menu
      allow(view).to receive(:new).and_return view_menu
      widget.select_row(device.sid)
    end

    context "for a MenuEvent" do
      let(:event) { { "EventType" => "MenuEvent", "ID" => "example_id" } }

      context "if any of the menus can respond to the event" do
        before do
          allow(system_menu).to receive(:handle).and_return nil
          allow(add_menu).to receive(:handle).and_return :result
        end

        it "delegates to that menu and returns the result" do
          expect(system_menu).to receive(:handle).with("example_id")
          expect(add_menu).to receive(:handle).with("example_id")
          expect(widget.handle(event)).to eq :result
        end
      end

      context "if none of the menus can respond to the event" do
        before do
          allow(system_menu).to receive(:handle).and_return nil
          allow(add_menu).to receive(:handle).and_return nil
          allow(modify_menu).to receive(:handle).and_return nil
          allow(view_menu).to receive(:handle).and_return nil
        end

        it "returns nil after trying to delegate to all the menus" do
          expect(system_menu).to receive(:handle).with("example_id")
          expect(add_menu).to receive(:handle).with("example_id")
          expect(modify_menu).to receive(:handle).with("example_id")
          expect(view_menu).to receive(:handle).with("example_id")
          expect(widget.handle(event)).to be_nil
        end
      end
    end

    context "for an event that is not a MenuEvent" do
      let(:event) { { "EventType" => "Whatever", "ID" => "example_id" } }

      it "returns nil without trying to delegate on the menus" do
        expect(system_menu).to_not receive(:handle)
        expect(add_menu).to_not receive(:handle)
        expect(modify_menu).to_not receive(:handle)
        expect(view_menu).to_not receive(:handle)
        expect(widget.handle(event)).to be_nil
      end
    end
  end

  describe "#help" do
    before { widget.select_page }

    it "includes some content about each menu" do
      menus = widget.contents.params[1]
      titles = menus.map { |m| m.params[0].gsub("&", "") }
      expect(titles.size).to be > 1

      help = widget.help
      titles.each do |title|
        expect(help).to include title
      end
    end
  end
end
