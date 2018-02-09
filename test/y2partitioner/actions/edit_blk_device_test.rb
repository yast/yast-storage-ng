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
require "y2partitioner/actions/controllers"
require "y2partitioner/actions/edit_blk_device"

describe Y2Partitioner::Actions::EditBlkDevice do
  before do
    allow(Yast::Wizard).to receive(:OpenNextBackDialog)
    allow(Yast::Wizard).to receive(:CloseDialog)

    devicegraph_stub(scenario)
  end

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { Y2Storage::BlkDevice.find_by_name(current_graph, dev_name) }

  describe "#run" do
    subject(:sequence) { described_class.new(device) }

    context "if called on an extended partition" do
      let(:scenario) { "mixed_disks.yml" }

      let(:dev_name) { "/dev/sdb4" }

      it "shows an error popup" do
        expect(Yast::Popup).to receive(:Error)
        sequence.run
      end

      it "quits returning :back" do
        expect(sequence.run).to eq :back
      end
    end

    context "if called on an LVM thin pool" do
      let(:scenario) { "lvm-two-vgs.yml" }

      before do
        vg = Y2Storage::LvmVg.find_by_vg_name(current_graph, "vg1")
        create_thin_provisioning(vg)
      end

      let(:dev_name) { "/dev/vg1/pool1" }

      it "shows an error popup" do
        expect(Yast::Popup).to receive(:Error)
        sequence.run
      end

      it "quits returning :back" do
        expect(sequence.run).to eq :back
      end
    end

    context "if called on a device that can be edited" do
      before do
        # Only to finish
        allow(Y2Partitioner::Dialogs::FormatAndMount).to receive(:run).and_return :abort
      end

      let(:scenario) { "complex-lvm-encrypt.yml" }

      let(:controller_class) { Y2Partitioner::Actions::Controllers::Filesystem }

      context "and the device is a partition" do
        let(:dev_name) { "/dev/sda1" }

        it "includes the partition device name in the title passed to the controller" do
          expect(controller_class).to receive(:new).with(device, /dev\/sda1/)
          sequence.run
        end
      end

      context "and the device is a logical volume" do
        let(:dev_name) { "/dev/vg0/lv1" }

        it "includes the VG device name and the LV name in the title passed to the controller" do
          expect(controller_class).to receive(:new) do |dev, title|
            expect(dev).to eq device
            expect(title).to include "/dev/vg0"
            expect(title).to include "lv1"
            expect(title).to_not include "/dev/vg0/lv1"
          end
          sequence.run
        end
      end

      context "and the device is an MD array" do
        before { Y2Storage::Md.create(current_graph, "/dev/md0") }

        let(:dev_name) { "/dev/md0" }

        it "includes the RAID device name in the title passed to the controller" do
          expect(controller_class).to receive(:new).with(device, /dev\/md0/)
          sequence.run
        end
      end

      context "if the user goes forward through all the dialogs" do
        before do
          allow(Y2Partitioner::Dialogs::FormatAndMount).to receive(:run).and_return :next
        end

        let(:dev_name) { "/dev/vg0/lv1" }

        it "returns :finish" do
          expect(sequence.run).to eq(:finish)
        end
      end

      context "if the user aborts the process at some point" do
        before do
          allow(Y2Partitioner::Dialogs::FormatAndMount).to receive(:run).and_return :abort
        end

        let(:dev_name) { "/dev/vg0/lv1" }

        it "returns :abort" do
          expect(sequence.run).to eq(:abort)
        end
      end
    end
  end
end
