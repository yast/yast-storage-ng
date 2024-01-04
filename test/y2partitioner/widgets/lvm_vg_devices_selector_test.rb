#!/usr/bin/env rspec

# Copyright (c) [2018-2021] SUSE LLC
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
require "y2partitioner/widgets/lvm_vg_devices_selector"
require "y2partitioner/actions/controllers/lvm_vg"

describe Y2Partitioner::Widgets::LvmVgDevicesSelector do
  using Y2Storage::Refinements::SizeCasts

  include_context "devices selector"

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:controller) { Y2Partitioner::Actions::Controllers::LvmVg.new(vg:) }

  let(:vg) { nil }

  subject(:widget) { described_class.new(controller) }

  before do
    devicegraph_stub(scenario)

    allow_any_instance_of(Y2Storage::BlkDevice).to receive(:hwinfo).and_return(Y2Storage::HWInfoDisk.new)

    initial_selected_devices.map { |d| controller.add_device(dev(d)) }
  end

  let(:scenario) { "complex-lvm-encrypt" }

  let(:initial_selected_devices) { ["/dev/sdc", "/dev/sda2"] }

  include_examples "CWM::CustomWidget"

  context "right after initialization" do
    describe "#contents" do
      it "displays all the unselected devices in the corresponding table" do
        items = table_values(unselected_table)
        expect(items.size).to eq(4)
        names = ["^/dev/sdb$", "^/dev/sda3$", "^/dev/sda4$", "^/dev/sde3$"]
        expect(rows_match?(items, *names)).to eq(true)
      end

      it "displays all the selected devices in the corresponding table and order" do
        items = table_values(selected_table)
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
        items = table_values(selected_table)
        expect(items.size).to eq(6)
        names = ["/dev/sdb$", "/dev/sdc$", "/dev/sda2$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
        expect(rows_match?(remove_sort_keys(items), *names)).to eq(true)
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
          items = table_values(selected_table)
          expect(items.size).to eq(2)
          names = ["/dev/sdc$", "/dev/sda2$"]
          expect(rows_match?(remove_sort_keys(items), *names)).to eq(true)
        end

        it "displays all the available devices in the corresponding table" do
          items = table_values(unselected_table)
          expect(items.size).to eq(4)
          names = ["/dev/sdb$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
          expect(rows_match?(remove_sort_keys(items), *names)).to eq(true)
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
          items = table_values(selected_table)
          expect(items.size).to eq(3)
          names = ["/dev/sdc$", "/dev/sda2$", "/dev/sda3$"]
          expect(rows_match?(remove_sort_keys(items), *names)).to eq(true)
        end

        it "displays all the available devices in the corresponding table" do
          items = table_values(unselected_table)
          expect(items.size).to eq(3)
          names = ["/dev/sdb$", "/dev/sda4$", "/dev/sde3$"]
          expect(rows_match?(remove_sort_keys(items), *names)).to eq(true)
        end
      end
    end
  end

  context "pushing the 'Remove All' button" do
    let(:event) { { "ID" => :remove_all } }

    before do
      allow(Yast2::Popup).to receive(:show)
    end

    describe "#handle" do
      context "when there is no committed pv in the vg" do
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

      context "when there are committed pvs in the volume group" do
        let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

        it "shows an error popup" do
          expect(Yast2::Popup).to receive(:show)
          widget.handle(event)
        end

        it "removes all uncommitted devices from the vg" do
          widget.handle(event)
          expect(controller.devices_in_vg.map(&:name)).to_not include("/dev/sdc", "/dev/sda2")
        end

        it "does not remove committed devices from the vg" do
          widget.handle(event)
          expect(controller.devices_in_vg.map(&:name)).to contain_exactly("/dev/sdd", "/dev/sde1")
        end

        it "makes all uncommitted devices available" do
          widget.handle(event)
          expect(controller.available_devices.map(&:name)).to contain_exactly(
            "/dev/sdb", "/dev/sdc", "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sde3"
          )
        end
      end
    end

    describe "#contents" do
      before { widget.handle(event) }

      let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

      it "does not display the removed devices in the 'selected' table" do
        items = table_values(selected_table)
        expect(items.size).to eq(2)
        names = ["/dev/sdd$", "/dev/sde1$"]
        expect(rows_match?(remove_sort_keys(items), *names)).to eq(true)
      end

      it "displays all the available devices in the 'unselected' table" do
        items = table_values(unselected_table)
        expect(items.size).to eq 6
        names = ["/dev/sdb$", "/dev/sdc$", "/dev/sda2$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
        expect(rows_match?(remove_sort_keys(items), *names)).to eq true
      end
    end
  end

  context "pushing the 'Remove' button" do
    let(:event) { { "ID" => :remove } }

    before do
      allow(selected_table).to receive(:value).and_return selection

      allow(Yast2::Popup).to receive(:show)
    end

    context "if there is no selected item in the 'selected' table" do
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
          items = table_values(selected_table)
          expect(items.size).to eq(2)
          names = ["/dev/sdc$", "/dev/sda2$"]
          expect(rows_match?(remove_sort_keys(items), *names)).to eq(true)
        end

        it "displays all the available devices in the corresponding table" do
          items = table_values(unselected_table)
          expect(items.size).to eq(4)
          names = ["/dev/sdb$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
          expect(rows_match?(remove_sort_keys(items), *names)).to eq(true)
        end
      end
    end

    context "if some item is selected in the 'selected' table" do
      let(:selection) { ["selected:device:#{dev(dev_name).sid}"] }

      let(:vg) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

      context "and the selected device is not committed" do
        let(:dev_name) { "/dev/sda2" }

        describe "#handle" do
          it "removes the device from the vg" do
            widget.handle(event)
            expect(controller.devices_in_vg.map(&:name)).to_not include(dev_name)
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
            items = table_values(selected_table)
            expect(items.size).to eq(3)
            names = ["/dev/sdc$", "/dev/sdd$", "/dev/sde1$"]
            expect(rows_match?(remove_sort_keys(items), *names)).to eq true
          end

          it "displays all the available devices in the corresponding table" do
            items = table_values(unselected_table)
            expect(items.size).to eq(5)
            names = ["/dev/sdb$", "/dev/sda2$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
            expect(rows_match?(remove_sort_keys(items), *names)).to eq true
          end
        end
      end

      context "and the selected device is committed" do
        let(:dev_name) { "/dev/sdd" }

        describe "#handle" do
          it "shows an error popup" do
            expect(Yast2::Popup).to receive(:show)
            widget.handle(event)
          end

          it "does not remove the device from the vg" do
            widget.handle(event)
            expect(controller.devices_in_vg.map(&:name)).to include(dev_name)
          end

          it "does not make the device available" do
            widget.handle(event)
            expect(controller.available_devices.map(&:name)).to contain_exactly(
              "/dev/sdb", "/dev/sda3", "/dev/sda4", "/dev/sde3"
            )
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table" do
            items = table_values(selected_table)
            expect(items.size).to eq(4)
            names = ["/dev/sda2$", "/dev/sdc$", "/dev/sdd$", "/dev/sde1$"]
            expect(rows_match?(remove_sort_keys(items), *names)).to eq true
          end

          it "displays all the available devices in the corresponding table" do
            items = table_values(unselected_table)
            expect(items.size).to eq(4)
            names = ["/dev/sdb$", "/dev/sda3$", "/dev/sda4$", "/dev/sde3$"]
            expect(rows_match?(remove_sort_keys(items), *names)).to eq true
          end
        end
      end
    end
  end

  describe "#validate" do
    let(:scenario) { "lvm_several_pvs" }

    before do
      allow(Yast2::Popup).to receive(:show)
    end

    context "if there are no selected devices" do
      let(:initial_selected_devices) { [] }

      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show).with(/at least one/, anything)

        widget.validate
      end

      it "returns false" do
        expect(widget.validate).to eq(false)
      end
    end

    context "if the vg size is less than the logical volumes size" do
      let(:initial_selected_devices) { ["/dev/sda1"] } # 2 GiB

      before do
        controller.vg.create_lvm_lv("test1", 1.GiB)
        controller.vg.create_lvm_lv("test2", 3.GiB)
      end

      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show).with(/size cannot be less than/, anything)

        widget.validate
      end

      it "returns false" do
        expect(widget.validate).to eq(false)
      end
    end

    context "if the number of physical volumes is less than max stripes" do
      let(:initial_selected_devices) { ["/dev/sda1", "/dev/sda3"] }

      before do
        test1 = controller.vg.create_lvm_lv("test1", 1.GiB)
        test2 = controller.vg.create_lvm_lv("test2", 1.GiB)
        test1.stripes = 2
        test2.stripes = 3
      end

      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show).with(/number of physcal volumes is not enough/, anything)

        widget.validate
      end

      it "returns false" do
        expect(widget.validate).to eq(false)
      end
    end

    context "if the physical volumes are not big enough to allocate the striped volumes" do
      let(:initial_selected_devices) { ["/dev/sda1", "/dev/sda2", "/dev/sda3"] }

      before do
        controller.vg.create_lvm_lv("test1", 1.GiB)
        test2 = controller.vg.create_lvm_lv("test2", 4.GiB)
        test2.stripes = 3 # max size is limited by /dev/sda2 (1 GiB)
      end

      it "shows an error popup" do
        expect(Yast2::Popup).to receive(:show).with(/selected devices are too small/, anything)

        widget.validate
      end

      it "returns false" do
        expect(widget.validate).to eq(false)
      end
    end

    context "if the logical volumes can be allocated" do
      let(:initial_selected_devices) { ["/dev/sda1", "/dev/sda2", "/dev/sda3"] }

      before do
        controller.vg.create_lvm_lv("test1", 1.GiB)
        test2 = controller.vg.create_lvm_lv("test2", 2.9.GiB)
        test2.stripes = 3 # max size is limited by /dev/sda2 (~1 GiB)
      end

      it "does not show an error popup" do
        expect(Yast2::Popup).to_not receive(:show)

        widget.validate
      end

      it "returns true" do
        expect(widget.validate).to eq(true)
      end
    end
  end
end
