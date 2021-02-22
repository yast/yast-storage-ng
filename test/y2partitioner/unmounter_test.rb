#!/usr/bin/env rspec

# Copyright (c) [2021] SUSE LLC
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

require_relative "test_helper"

require "y2partitioner/unmounter"

describe Y2Partitioner::Unmounter do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(device) }

  let(:device) { device_graph.find_by_name(device_name).filesystem }

  let(:device_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  before do
    # Avoid to generate a new mount point object every time in order to make testing easier
    allow(device).to receive(:mount_point).and_return(device.mount_point)
  end

  let(:scenario) { "mixed_disks" }

  let(:device_name) { "/dev/sdb5" }

  describe "#unmount" do
    it "tries to unmount the device" do
      expect(device.mount_point).to receive(:immediate_deactivate)

      subject.unmount
    end

    context "when the device is correctly unmounted" do
      before do
        allow(device.mount_point).to receive(:immediate_deactivate)
      end

      it "returns true" do
        expect(subject.unmount).to eq(true)
      end
    end

    context "when the device cannot be unmounted" do
      before do
        allow(device.mount_point).to receive(:immediate_deactivate).and_raise(Storage::Exception)
      end

      it "returns false" do
        expect(subject.unmount).to eq(false)
      end
    end
  end

  describe "#error?" do
    context "when the device was correctly unmounted" do
      before do
        allow(device.mount_point).to receive(:immediate_deactivate)
      end

      it "returns false" do
        subject.unmount

        expect(subject.error?).to eq(false)
      end
    end

    context "when the device was not correctly unmounted" do
      before do
        allow(device.mount_point).to receive(:immediate_deactivate).and_raise(Storage::Exception)
      end

      it "returns true" do
        subject.unmount

        expect(subject.error?).to eq(true)
      end
    end
  end

  describe "#error" do
    context "when the device was correctly unmounted" do
      before do
        allow(device.mount_point).to receive(:immediate_deactivate)
      end

      it "returns nil" do
        subject.unmount

        expect(subject.error).to be_nil
      end
    end

    context "when the device was not correctly unmounted" do
      before do
        allow(device.mount_point).to receive(:immediate_deactivate)
          .and_raise(Storage::Exception, "Error unmounting")
      end

      it "returns the error message" do
        subject.unmount

        expect(subject.error).to eq("Error unmounting")
      end
    end
  end
end
