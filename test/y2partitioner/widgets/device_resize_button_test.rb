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
require "y2partitioner/widgets/device_resize_button"
require "y2partitioner/widgets/configurable_blk_devices_table"
require "y2partitioner/device_graphs"

describe Y2Partitioner::Widgets::DeviceResizeButton do
  subject { described_class.new(table: table) }

  let(:table) do
    instance_double(Y2Partitioner::Widgets::ConfigurableBlkDevicesTable,
      selected_device: device)
  end

  let(:device) { nil }

  include_examples "CWM::PushButton"

  describe "#handle" do
    context "when no device is selected" do
      let(:device) { nil }

      it "shows an error message" do
        expect(Yast::Popup).to receive(:Error)
        subject.handle
      end

      it "returns nil" do
        expect(subject.handle).to be(nil)
      end
    end

    context "when a device is selected" do
      before do
        devicegraph_stub(scenario)
      end

      let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

      let(:device) { Y2Storage::BlkDevice.find_by_name(current_graph, device_name) }

      context "and the device is a MD RAID" do
        before do
          allow_any_instance_of(Y2Partitioner::Actions::ResizeMd).to receive(:run)
            .and_return(action_result)
        end

        let(:action_result) { nil }

        let(:scenario) { "md_raid.xml" }

        let(:device_name) { "/dev/md/md0" }

        it "performs the action for resizing a MD RAID" do
          expect_any_instance_of(Y2Partitioner::Actions::ResizeMd).to receive(:run)
          subject.handle
        end

        context "and resize action is correctly performed" do
          let(:action_result) { :finish }

          it "returns :redraw" do
            expect(subject.handle).to eq(:redraw)
          end
        end

        context "and resize action is not correctly performed" do
          let(:action_result) { :back }

          it "returns nil" do
            expect(subject.handle).to be_nil
          end
        end
      end

      context "and the device is a partition" do
        before do
          allow_any_instance_of(Y2Partitioner::Actions::ResizeBlkDevice).to receive(:run)
            .and_return(action_result)

          allow_any_instance_of(Y2Storage::Partition).to receive(:detect_resize_info)
            .and_return(nil)
        end

        let(:action_result) { nil }

        let(:scenario) { "mixed_disks.yml" }

        let(:device_name) { "/dev/sda1" }

        it "performs the action for resizing a partition" do
          expect_any_instance_of(Y2Partitioner::Actions::ResizeBlkDevice).to receive(:run)
          subject.handle
        end

        context "and resize action is correctly performed" do
          let(:action_result) { :finish }

          it "returns :redraw" do
            expect(subject.handle).to eq(:redraw)
          end
        end

        context "and resize action is not correctly performed" do
          let(:action_result) { :back }

          it "returns nil" do
            expect(subject.handle).to be_nil
          end
        end
      end

      context "and the device is an LVM logical volume" do
        before do
          allow_any_instance_of(Y2Partitioner::Actions::ResizeBlkDevice).to receive(:run)
            .and_return(action_result)

          allow_any_instance_of(Y2Storage::LvmLv).to receive(:detect_resize_info)
            .and_return(nil)
        end

        let(:action_result) { nil }

        let(:scenario) { "complex-lvm-encrypt" }

        let(:device_name) { "/dev/vg1/lv2" }

        it "performs the action for resizing a logical volume" do
          expect_any_instance_of(Y2Partitioner::Actions::ResizeBlkDevice).to receive(:run)
          subject.handle
        end

        context "and resize action is correctly performed" do
          let(:action_result) { :finish }

          it "returns :redraw" do
            expect(subject.handle).to eq(:redraw)
          end
        end

        context "and resize action is not correctly performed" do
          let(:action_result) { :back }

          it "returns nil" do
            expect(subject.handle).to be_nil
          end
        end
      end

      context "and the device is a LVM volume group" do
        before do
          allow_any_instance_of(Y2Partitioner::Actions::ResizeLvmVg).to receive(:run)
            .and_return(action_result)
        end

        let(:device) { Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg0") }

        let(:action_result) { nil }

        let(:scenario) { "lvm-two-vgs.yml" }

        it "performs the action for resizing a partition" do
          expect_any_instance_of(Y2Partitioner::Actions::ResizeLvmVg).to receive(:run)
          subject.handle
        end

        context "and resize action is correctly performed" do
          let(:action_result) { :finish }

          it "returns :redraw" do
            expect(subject.handle).to eq(:redraw)
          end
        end

        context "and resize action is not correctly performed" do
          let(:action_result) { :back }

          it "returns nil" do
            expect(subject.handle).to be_nil
          end
        end
      end

      context "and resize action is not supported for the device" do
        let(:scenario) { "mixed_disks.yml" }

        let(:device_name) { "/dev/sda" }

        it "shows an error popup" do
          expect(Yast::Popup).to receive(:Error)
          subject.handle
        end

        it "returns nil" do
          expect(subject.handle).to be_nil
        end
      end
    end
  end
end
