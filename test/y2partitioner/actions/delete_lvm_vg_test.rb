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
require "y2partitioner/actions/delete_lvm_vg"

describe Y2Partitioner::Actions::DeleteLvmVg do
  before { devicegraph_stub("lvm-two-vgs") }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }
  let(:device) { device_graph.find_by_name(device_name) }

  subject(:action) { described_class.new(device) }

  describe "#run" do
    let(:device_name) { "/dev/vg1" }

    let(:accept) { nil }

    context "when deleting an empty volume group" do
      before { device.remove_descendants }

      it "shows a confirmation message with the device name" do
        expect(Yast2::Popup).to receive(:show) do |string, _anything|
          expect(string).to include device_name
        end
        action.run
      end
    end

    context "when deleting a volume group with LVs" do
      it "shows a detailed confirmation message including all the LVs and the VG name" do
        expect(action).to receive(:confirm_recursive_delete)
          .with(device, anything, anything, /vg1/)
          .and_call_original

        action.run
      end
    end

    context "when the confirm message is not accepted" do
      before { allow(action).to receive(:confirm_recursive_delete).and_return false }

      it "does not delete the VG" do
        action.run
        expect(device_graph.find_by_name(device_name)).to_not be_nil
      end

      it "does not delete the descendant devices like LVs" do
        descendants = device.descendants
        action.run
        expect(device.descendants).to contain_exactly(*descendants)
      end

      it "does not delete or modify the associated LvmPv devices" do
        devices = device.lvm_pvs.map(&:blk_device)
        action.run
        expect(devices.map(&:lvm_pv)).to all(be_a(Y2Storage::LvmPv))
        expect(devices.map(&:lvm_pv).map(&:lvm_vg)).to all(eq(device))
      end

      it "does not delete the devices hosting the LvmPv devices" do
        devices = device.lvm_pvs.map(&:blk_device)
        action.run
        expect(devices.map { |dev| dev.exists_in_devicegraph?(device_graph) }).to all(eq(true))
      end

      it "returns :back" do
        expect(action.run).to eq(:back)
      end
    end

    context "when the confirm message is accepted" do
      before { allow(action).to receive(:confirm_recursive_delete).and_return true }

      it "deletes the VG" do
        action.run
        expect(device_graph.find_by_name(device_name)).to be_nil
      end

      it "deletes the descendant devices like LVs" do
        lv_names = device.lvm_lvs.map(&:name)
        action.run
        lvs = lv_names.map { |lv| device_graph.find_by_name(lv) }.compact
        expect(lvs).to be_empty
      end

      it "deletes the associated LvmPv devices" do
        devices = device.lvm_pvs.map(&:blk_device)
        action.run
        expect(devices.map(&:lvm_pv)).to all(be_nil)
      end

      it "does not delete the devices hosting the LvmPv devices" do
        devices = device.lvm_pvs.map(&:blk_device)
        action.run
        expect(devices.map { |dev| dev.exists_in_devicegraph?(device_graph) }).to all(eq(true))
      end

      it "refresh btrfs subvolumes shadowing" do
        expect(Y2Storage::Filesystems::Btrfs).to receive(:refresh_subvolumes_shadowing)
        subject.run
      end

      it "returns :finish" do
        expect(subject.run).to eq(:finish)
      end
    end
  end
end
