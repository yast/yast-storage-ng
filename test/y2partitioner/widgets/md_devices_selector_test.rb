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
require_relative "#{TEST_PATH}/support/devices_selector_context"

require "cwm/rspec"
require "y2partitioner/widgets/md_devices_selector"
require "y2partitioner/actions/controllers/md"

describe Y2Partitioner::Widgets::MdDevicesSelector do
  include_context "devices selector"

  let(:controller) { Y2Partitioner::Actions::Controllers::Md.new }

  subject(:widget) { described_class.new(controller) }

  before do
    devicegraph_stub("complex-lvm-encrypt.yml")

    controller.add_device(dev("/dev/sde3"))
    controller.add_device(dev("/dev/sda3"))
  end

  include_examples "CWM::CustomWidget"

  context "right after initialization" do
    describe "#contents" do
      it "displays all the unselected devices in the corresponding table" do
        items = unselected_table.items
        expect(rows_match?(items, "^/dev/sda2$", "^/dev/sda4$", "^/dev/sdb$", "^/dev/sdc$")).to eq true
      end

      it "displays all the selected devices in the corresponding table and order" do
        items = selected_table.items
        expect(rows_match?(items, "^/dev/sde3$", "^/dev/sda3$")).to eq true
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

      it "adds all the available devices at the end of the MD array" do
        widget.handle(event)
        expect(controller.devices_in_md.map(&:name)).to contain_exactly(
          "/dev/sde3", "/dev/sda3", "/dev/sda2", "/dev/sda4", "/dev/sdb", "/dev/sdc"
        )
      end
    end

    describe "#contents" do
      before { widget.handle(event) }

      it "displays all the selected devices in the corresponding table" do
        items = selected_table.items
        expect(items.size).to eq 6
        names = ["/dev/sde3$", "/dev/sda3$", "/dev/sda2$", "/dev/sda4$", "/dev/sdb$", "/dev/sdc$"]
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
          expect(controller.devices_in_md.map(&:name)).to eq ["/dev/sde3", "/dev/sda3"]
          expect(controller.available_devices.map(&:name))
            .to contain_exactly("/dev/sda2", "/dev/sda4", "/dev/sdb", "/dev/sdc")
        end
      end

      describe "#contents" do
        before { widget.handle(event) }

        it "displays all the selected devices in the corresponding table and order" do
          items = selected_table.items
          expect(rows_match?(items, "/dev/sde3$", "/dev/sda3$")).to eq true
        end

        it "displays all the available devices in the corresponding table and order" do
          items = unselected_table.items
          expect(rows_match?(items, "/dev/sda2$", "/dev/sda4$", "/dev/sdb$", "/dev/sdc$")).to eq true
        end
      end
    end

    context "if some items where selected in the 'unselected' table" do
      let(:selection) { ["unselected:device:#{dev("/dev/sda2").sid}"] }

      describe "#handle" do
        it "adds the devices at the end of the MD RAID" do
          widget.handle(event)
          expect(controller.devices_in_md.map(&:name)).to eq [
            "/dev/sde3", "/dev/sda3", "/dev/sda2"
          ]
        end

        it "causes the device to not be longer available" do
          widget.handle(event)
          expect(controller.available_devices.map(&:name)).to_not include("/dev/sda2")
        end
      end

      describe "#contents" do
        before { widget.handle(event) }

        it "displays all the selected devices in the corresponding table and order" do
          items = selected_table.items
          expect(items.size).to eq 3
          expect(rows_match?(items, "/dev/sde3$", "/dev/sda3$", "/dev/sda2$")).to eq true
        end

        it "displays all the available devices in the corresponding table" do
          items = unselected_table.items
          expect(items.size).to eq 3
          expect(rows_match?(items, "/dev/sda4$", "/dev/sdb", "/dev/sdc")).to eq true
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
          "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sdb", "/dev/sdc", "/dev/sde3"
        )
      end
    end

    describe "#contents" do
      before { widget.handle(event) }

      it "displays no selected devices" do
        items = selected_table.items
        expect(items).to be_empty
      end

      it "displays all the available devices in the corresponding table and order" do
        items = unselected_table.items
        expect(items.size).to eq 6
        names = ["/dev/sda2$", "/dev/sda3$", "/dev/sda4$", "/dev/sdb$", "/dev/sdc$", "/dev/sde3$"]
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
          expect(controller.devices_in_md.map(&:name)).to eq ["/dev/sde3", "/dev/sda3"]
          expect(controller.available_devices.map(&:name))
            .to contain_exactly("/dev/sda2", "/dev/sda4", "/dev/sdb", "/dev/sdc")
        end
      end

      describe "#contents" do
        before { widget.handle(event) }

        it "displays all the selected devices in the corresponding table and order" do
          items = selected_table.items
          expect(rows_match?(items, "/dev/sde3$", "/dev/sda3$")).to eq true
        end

        it "displays all the available devices in the corresponding table and order" do
          items = unselected_table.items
          expect(rows_match?(items, "/dev/sda2$", "/dev/sda4$", "/dev/sdb$", "/dev/sdc$")).to eq true
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
            "/dev/sda2", "/dev/sda3", "/dev/sda4", "/dev/sdb", "/dev/sdc"
          )
        end
      end

      describe "#contents" do
        before { widget.handle(event) }

        it "displays all the selected devices in the corresponding table" do
          items = selected_table.items
          expect(rows_match?(items, "/dev/sde3$")).to eq true
        end

        it "displays all the available devices in the corresponding table and order" do
          items = unselected_table.items
          expect(rows_match?(items, "/dev/sda2$", "/dev/sda3$", "/dev/sda4$")).to eq true
        end
      end
    end
  end

  context "ordering devices" do
    before do
      allow(selected_table).to receive(:value).and_return selection

      # Let's start with all devices in the 'selected' list, to have more
      # testing options
      controller.add_device(dev("/dev/sda2"))
      controller.add_device(dev("/dev/sda4"))
    end

    context "pushing the 'Up' button" do
      let(:event) { { "ID" => :up } }

      context "if there were no marked item in the 'selected' table" do
        let(:selection) { [] }

        describe "#handle" do
          it "does not alter the controller lists (no changes)" do
            widget.handle(event)
            expect(controller.devices_in_md.map(&:name)).to eq [
              "/dev/sde3", "/dev/sda3", "/dev/sda2", "/dev/sda4"
            ]
            expect(controller.available_devices.map(&:name))
              .to contain_exactly("/dev/sdb", "/dev/sdc")
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "keeps displaying all the selected devices in the corresponding table and order" do
            names = ["/dev/sde3$", "/dev/sda3$", "/dev/sda2$", "/dev/sda4$"]
            expect(rows_match?(selected_table.items, *names)).to eq true
          end
        end
      end

      context "if there were some marked items in the 'selected' table" do
        let(:selection) do
          ["selected:device:#{dev("/dev/sda3").sid}", "selected:device:#{dev("/dev/sda4").sid}"]
        end

        describe "#handle" do
          it "moves all the chosen devices one position forward in the MD RAID" do
            widget.handle(event)
            expect(controller.devices_in_md.map(&:name)).to eq [
              "/dev/sda3", "/dev/sde3", "/dev/sda4", "/dev/sda2"
            ]
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table and order" do
            names = ["/dev/sda3$", "/dev/sde3$", "/dev/sda4$", "/dev/sda2$"]
            expect(rows_match?(selected_table.items, *names)).to eq true
          end
        end
      end
    end

    context "pushing the 'Down' button" do
      let(:event) { { "ID" => :down } }

      context "if there was no marked item in the 'selected' table" do
        let(:selection) { [] }

        describe "#handle" do
          it "does not alter the controller lists (no changes)" do
            widget.handle(event)
            expect(controller.devices_in_md.map(&:name)).to eq [
              "/dev/sde3", "/dev/sda3", "/dev/sda2", "/dev/sda4"
            ]
            expect(controller.available_devices.map(&:name))
              .to contain_exactly("/dev/sdb", "/dev/sdc")
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "keeps displaying all the selected devices in the corresponding table and order" do
            names = ["/dev/sde3$", "/dev/sda3$", "/dev/sda2$", "/dev/sda4$"]
            expect(rows_match?(selected_table.items, *names)).to eq true
          end
        end
      end

      context "if there were some marked items in the 'selected' table" do
        let(:selection) { ["selected:device:#{dev("/dev/sda3").sid}"] }

        describe "#handle" do
          it "moves all the chosen devices one position backwards in the MD RAID" do
            widget.handle(event)
            expect(controller.devices_in_md.map(&:name)).to eq [
              "/dev/sde3", "/dev/sda2", "/dev/sda3", "/dev/sda4"
            ]
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table and order" do
            names = ["/dev/sde3$", "/dev/sda2$", "/dev/sda3$", "/dev/sda4$"]
            expect(rows_match?(selected_table.items, *names)).to eq true
          end
        end
      end
    end

    context "pushing the 'Top' button" do
      let(:event) { { "ID" => :top } }

      context "if there were no marked item in the 'selected' table" do
        let(:selection) { [] }

        describe "#handle" do
          it "does not alter the controller lists (no changes)" do
            widget.handle(event)
            expect(controller.devices_in_md.map(&:name)).to eq [
              "/dev/sde3", "/dev/sda3", "/dev/sda2", "/dev/sda4"
            ]
            expect(controller.available_devices.map(&:name))
              .to contain_exactly("/dev/sdb", "/dev/sdc")
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "keeps displaying all the selected devices in the corresponding table and order" do
            names = ["/dev/sde3$", "/dev/sda3$", "/dev/sda2$", "/dev/sda4$"]
            expect(rows_match?(selected_table.items, *names)).to eq true
          end
        end
      end

      context "if there were some marked items in the 'selected' table" do
        let(:selection) do
          ["selected:device:#{dev("/dev/sda3").sid}", "selected:device:#{dev("/dev/sda4").sid}"]
        end

        describe "#handle" do
          it "moves all the chosen devices to the beginning in the MD RAID" do
            widget.handle(event)
            expect(controller.devices_in_md.map(&:name)).to eq [
              "/dev/sda3", "/dev/sda4", "/dev/sde3", "/dev/sda2"
            ]
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table and order" do
            names = ["/dev/sda3$", "/dev/sda4$", "/dev/sde3$", "/dev/sda2$"]
            expect(rows_match?(selected_table.items, *names)).to eq true
          end
        end
      end
    end

    context "pushing the 'Bottom' button" do
      let(:event) { { "ID" => :bottom } }

      context "if there were no marked item in the 'selected' table" do
        let(:selection) { [] }

        describe "#handle" do
          it "does not alter the controller lists (no changes)" do
            widget.handle(event)
            expect(controller.devices_in_md.map(&:name)).to eq [
              "/dev/sde3", "/dev/sda3", "/dev/sda2", "/dev/sda4"
            ]
            expect(controller.available_devices.map(&:name))
              .to contain_exactly("/dev/sdb", "/dev/sdc")
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "keeps displaying all the selected devices in the corresponding table and order" do
            names = ["/dev/sde3$", "/dev/sda3$", "/dev/sda2$", "/dev/sda4$"]
            expect(rows_match?(selected_table.items, *names)).to eq true
          end
        end
      end

      context "if there were some marked items in the 'selected' table" do
        let(:selection) { ["selected:device:#{dev("/dev/sde3").sid}"] }

        describe "#handle" do
          it "moves all the chosen devices to the end in the MD RAID" do
            widget.handle(event)
            expect(controller.devices_in_md.map(&:name)).to eq [
              "/dev/sda3", "/dev/sda2", "/dev/sda4", "/dev/sde3"
            ]
          end
        end

        describe "#contents" do
          before { widget.handle(event) }

          it "displays all the selected devices in the corresponding table and order" do
            names = ["/dev/sda3$", "/dev/sda2$", "/dev/sda4$", "/dev/sde3$"]
            expect(rows_match?(selected_table.items, *names)).to eq true
          end
        end
      end
    end
  end

  describe "#validate" do
    before do
      allow(subject).to receive(:filesystem_errors).and_return(warnings)
      allow(Yast2::Popup).to receive(:show)
        .with(anything, hash_including(headline: :warning)).and_return(accept)
    end

    let(:warnings) { [] }

    let(:accept) { nil }

    context "if there are not enough devices in the MD array" do
      before do
        controller.remove_device(dev("/dev/sda3"))
      end

      let(:warnings) { ["warning1"] }

      it "shows an error pop-up" do
        expect(Yast2::Popup).to receive(:show).with(anything, hash_including(headline: :error))
        widget.validate
      end

      it "does not show warnings" do
        expect(Yast2::Popup).to_not receive(:show).with(anything, hash_including(headline: :warning))
        widget.validate
      end

      it "returns false" do
        allow(Yast2::Popup).to receive(:show)
        expect(widget.validate).to eq(false)
      end
    end

    context "if there are enough devices in the MD array" do
      it "does not show an error pop-up" do
        expect(Yast2::Popup).to_not receive(:show).with(anything, hash_including(headline: :error))
        widget.validate
      end

      context "and there are no warnings" do
        let(:warnings) { [] }

        it "does not show a warning popup" do
          expect(Yast2::Popup).to_not receive(:show)
          subject.validate
        end

        it "returns true" do
          expect(subject.validate).to eq(true)
        end
      end

      context "and there are warnings" do
        let(:warnings) { ["warning1", "warning2"] }

        it "shows a warning popup" do
          expect(Yast2::Popup).to receive(:show).with(anything, hash_including(headline: :warning))
          subject.validate
        end

        context "and the user accepts" do
          let(:accept) { :yes }

          it "returns true" do
            expect(subject.validate).to eq(true)
          end
        end

        context "and the user declines" do
          let(:accept) { :no }

          it "returns false" do
            expect(subject.validate).to eq(false)
          end
        end
      end
    end
  end
end
