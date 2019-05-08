#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2019] SUSE LLC
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
require_relative "#{TEST_PATH}/support/devices_selector_context"

require "cwm/rspec"
require "y2partitioner/widgets/btrfs_devices_selector"
require "y2partitioner/actions/controllers/btrfs_devices"

describe Y2Partitioner::Widgets::BtrfsDevicesSelector do
  include_context "devices selector"

  subject(:widget) { described_class.new(controller) }
  let(:controller) { Y2Partitioner::Actions::Controllers::BtrfsDevices.new }
  let(:devicegraph) { "complex-lvm-encrypt" }

  let(:available_devices_names) do
    ["/dev/sda1", "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sdb", "/dev/sdc", "/dev/sde3",
     "/dev/sdf1", "/dev/vg0/lv2", "/dev/vg1/lv1", "/dev/vg1/lv2"]
  end

  let(:selected_devices_names) do
    ["/dev/sde3", "/dev/sda3"]
  end

  let(:unselected_devices_names) do
    available_devices_names - selected_devices_names
  end

  let(:selected_items) { selected_table.items }
  let(:unselected_items) { unselected_table.items }
  let(:expected_selected_items) { selected_devices_names.map { |device_name| "^#{device_name}$" } }
  let(:expected_unselected_items) { unselected_devices_names.map { |device_name| "^#{device_name}$" } }

  before do
    devicegraph_stub(devicegraph)

    # Pre-select some devices
    selected_devices_names.each do |device_name|
      device = dev(device_name)
      controller.add_device(device)
    end
  end

  context "right after initialization" do
    describe "#contents" do
      it "displays all the unselected devices in the corresponding table" do
        expect(rows_match?(unselected_items, *expected_unselected_items)).to eq true
      end

      it "displays all the selected devices in the corresponding table" do
        expect(rows_match?(selected_items, *expected_selected_items)).to eq true
      end
    end
  end

  context "pushing the 'Add All' button" do
    let(:event) { { "ID" => :add_all } }

    before do
      widget.handle(event)
    end

    describe "#handle" do
      it "leaves no available devices" do
        expect(controller.available_devices).to be_empty
      end

      it "selects all the available devices" do
        expect(controller.selected_devices.map(&:name)).to match_array(available_devices_names)
      end
    end

    describe "#contents" do
      it "displays all the selected devices in the corresponding table" do
        expect(rows_match?(selected_items, *expected_selected_items)).to eq true
      end

      it "displays none device as unselected" do
        expect(unselected_items).to be_empty
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
        it "does not alter the selected devices" do
          expect { widget.handle(event) }.to_not change { controller.selected_devices }
        end

        it "does not alter the unselected devices" do
          expect { widget.handle(event) }.to_not change { controller.available_devices }
        end
      end

      describe "#contents" do
        before do
          widget.handle(event)
        end

        it "displays all the selected devices in the corresponding table" do
          expect(rows_match?(selected_items, *expected_selected_items)).to eq true
        end

        it "displays all the available devices in the corresponding table" do
          expect(rows_match?(unselected_items, *expected_unselected_items)).to eq true
        end
      end
    end
  end

  context "pushing the 'Remove All' button" do
    let(:event) { { "ID" => :remove_all } }

    before do
      widget.handle(event)
    end

    describe "#handle" do
      it "removes all devices from the selected devices" do
        expect(controller.selected_devices).to be_empty
      end

      it "makes all devices available" do
        expect(controller.available_devices.map(&:name)).to match_array(available_devices_names)
      end
    end

    describe "#contents" do
      it "does not display selected devices" do
        expect(selected_items).to be_empty
      end

      it "displays all the available devices as unselected" do
        expect(rows_match?(unselected_items, *expected_unselected_items)).to eq true
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
        it "does not change selected devices" do
          expect { widget.handle(event) }.to_not change { controller.selected_devices }
        end

        it "does not change available devices" do
          expect { widget.handle(event) }.to_not change { controller.available_devices }
        end
      end

      describe "#contents" do
        before do
          widget.handle(event)
        end

        it "displays all the selected devices in the corresponding table and order" do
          expect(rows_match?(selected_items, *expected_selected_items)).to eq true
        end

        it "displays all the available devices in the corresponding table and order" do
          expect(rows_match?(unselected_items, *expected_unselected_items)).to eq true
        end
      end
    end

    context "if some items where selected in the 'selected' table" do
      let(:device_name) { "/dev/sda3" }
      let(:selected_device) { dev(device_name) }
      let(:selection) { ["selected:device:#{selected_device.sid}"] }

      before do
        widget.handle(event)
      end

      describe "#handle" do
        it "removes the selected device from selected devices" do
          expect(controller.selected_devices).to_not include(selected_device)
        end

        it "makes the device available" do
          expect(controller.available_devices).to include(selected_device)
        end
      end

      describe "#contents" do
        it "displays all the selected devices in the corresponding table" do
          expected_items = expected_selected_items.reject { |item| item.include?(device_name) }

          expect(rows_match?(selected_items, *expected_items)).to eq true
        end

        it "displays all the available devices in the corresponding" do
          expected_items = expected_unselected_items.append("#{device_name}$")

          expect(rows_match?(unselected_items, *expected_items)).to eq true
        end
      end
    end
  end

  describe "#contents" do
    it "does not display the selected size" do
      expect(Yast).to_not receive(:Id).with(:selected_size)
      expect(Yast::UI).to_not receive(:ReplaceWidget)

      subject.refresh
    end

    it "does not display the unselected size" do
      expect(Yast).to_not receive(:Id).with(:unselected_size)
      expect(Yast::UI).to_not receive(:ReplaceWidget)

      subject.refresh
    end
  end

  describe "#validate" do
    before do
      allow(Yast2::Popup).to receive(:show)
    end

    context "when there is any device selected" do
      it "returns true" do
        expect(subject.validate).to eq(true)
      end

      it "do not display errors" do
        expect(Yast2::Popup).to_not receive(:show)

        subject.validate
      end
    end

    context "when there is none device selected" do
      before do
        selected_devices_names.each do |device_name|
          device = dev(device_name)
          controller.remove_device(device)
        end
      end

      it "returns false" do
        expect(subject.validate).to eq(false)
      end

      it "displays an error popup" do
        expect(Yast2::Popup).to receive(:show).with(anything, hash_including(headline: :error))

        subject.validate
      end
    end
  end
end
