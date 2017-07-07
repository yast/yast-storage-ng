#!/usr/bin/env rspec
#
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

require_relative "../spec_helper"
require "y2storage/planned"

describe Y2Storage::Planned::Md do
  subject(:planned_md) { described_class.new }

  describe "#add_devices" do
    let(:sda1) { double("Y2Storage::Partition", name: "/dev/sda1") }
    let(:sda2) { double("Y2Storage::Partition", name: "/dev/sda2") }
    let(:sdb1) { double("Y2Storage::Partition", name: "/dev/sdb1") }
    let(:sdb2) { double("Y2Storage::Partition", name: "/dev/sdb2") }
    let(:devices) { [sdb1, sdb2, sda2, sda1] }
    let(:real_md) { double("Y2Storage::Md") }

    it "calls Y2Storage::Md#add_device for all the devices" do
      expect(real_md).to receive(:add_device).exactly(4).times
      planned_md.add_devices(devices, real_md)
    end

    context "if #devices_order is not set" do
      it "adds the devices in name's alphabetical order" do
        expect(real_md).to receive(:add_device).with(sda1).ordered
        expect(real_md).to receive(:add_device).with(sda2).ordered
        expect(real_md).to receive(:add_device).with(sdb1).ordered
        expect(real_md).to receive(:add_device).with(sdb2).ordered

        planned_md.add_devices(devices, real_md)
      end
    end

    context "if #devices_order is set" do
      before do
        planned_md.devices_order = ["/dev/sdb2", "/dev/sda1", "/dev/sda2", "/dev/sdb1"]
      end

      it "adds the devices in the specified order" do
        expect(real_md).to receive(:add_device).with(sdb2).ordered
        expect(real_md).to receive(:add_device).with(sda1).ordered
        expect(real_md).to receive(:add_device).with(sda2).ordered
        expect(real_md).to receive(:add_device).with(sdb1).ordered

        planned_md.add_devices(devices, real_md)
      end

      context "if #devices_order contains devices that are not in the list" do
        before do
          planned_md.devices_order = ["/dev/sdb2", "/dev/sda1", "/dev/sda3", "/dev/sda2", "/dev/sdb1"]
        end

        it "adds the devices in the specified order" do
          expect(real_md).to receive(:add_device).with(sdb2).ordered
          expect(real_md).to receive(:add_device).with(sda1).ordered
          expect(real_md).to receive(:add_device).with(sda2).ordered
          expect(real_md).to receive(:add_device).with(sdb1).ordered

          planned_md.add_devices(devices, real_md)
        end

        it "does not try to add additional devices" do
          expect(real_md).to receive(:add_device).exactly(4).times
          planned_md.add_devices(devices, real_md)
        end
      end

      context "if some of the devices are not in #devices_order" do
        before { planned_md.devices_order = ["/dev/sdb2", "/dev/sda2"] }

        it "adds all the devices" do
          expect(real_md).to receive(:add_device).exactly(4).times
          planned_md.add_devices(devices, real_md)
        end

        it "adds first the sorted devices and then the rest (alphabetically)" do
          expect(real_md).to receive(:add_device).with(sdb2).ordered
          expect(real_md).to receive(:add_device).with(sda2).ordered
          expect(real_md).to receive(:add_device).with(sda1).ordered
          expect(real_md).to receive(:add_device).with(sdb1).ordered

          planned_md.add_devices(devices, real_md)
        end
      end
    end
  end
end
