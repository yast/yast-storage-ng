#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::DevicegraphSanitizer do
  before do
    Y2Storage::StorageManager.create_test_instance
  end

  subject { described_class.new(devicegraph) }

  describe "#errors" do
    context "when the devicegraph contains errors" do
      let(:devicegraph) { devicegraph_from("lvm-errors1-devicegraph.xml") }

      before do
        Y2Storage::LvmVg.create(devicegraph, "test3")
      end

      it "returns a list of errors" do
        expect(subject.errors).to be_a(Array)
      end

      it "contains an error for each LVM VG with missing PVs" do
        vg1 = devicegraph.find_by_name("/dev/test1")
        vg2 = devicegraph.find_by_name("/dev/test2")

        expect(subject.errors.map(&:device)).to contain_exactly(vg1, vg2)
      end

      it "does not contain an error for correct LVM VGs" do
        vg3 = devicegraph.find_by_name("/dev/test3")

        expect(subject.errors.map(&:device)).to_not include(vg3)
      end

      it "does not generate new errors in sequential calls" do
        errors = subject.errors
        expect(subject.errors).to eq(errors)
        expect(subject.errors.object_id).to eq(errors.object_id)
      end
    end

    context "when the devicegraph does not contain errors" do
      let(:devicegraph) { devicegraph_from("lvm-two-vgs") }

      it "returns an empty list" do
        expect(subject.errors).to be_empty
      end
    end
  end

  describe "#sanitized_devicegraph" do
    RSpec.shared_examples "sanitized devicegraph" do
      it "returns a new devicegraph" do
        expect(subject.sanitized_devicegraph).to_not equal(devicegraph)
      end

      it "does not modify the initial devicegraph" do
        initial_devicegraph = devicegraph.dup
        subject.sanitized_devicegraph

        expect(devicegraph).to eq(initial_devicegraph)
      end

      it "does not create a new devicegraph in sequential calls" do
        sanitized = subject.sanitized_devicegraph
        expect(subject.sanitized_devicegraph).to equal(sanitized)
      end
    end

    context "when the devicegraph contains errors" do
      let(:devicegraph) { devicegraph_from("lvm-errors1-devicegraph.xml") }

      before do
        Y2Storage::LvmVg.create(devicegraph, "test3")
      end

      include_examples "sanitized devicegraph"

      it "returns a devicegraph without the LVM VGs with missing PVs" do
        vg3 = devicegraph.find_by_name("/dev/test3")

        expect(devicegraph.lvm_vgs.size).to eq(3)
        expect(subject.sanitized_devicegraph.lvm_vgs).to contain_exactly(vg3)
      end
    end

    context "when the devicegraph does not contain errors" do
      let(:devicegraph) { devicegraph_from("lvm-two-vgs") }

      before do
        Y2Storage::LvmVg.create(devicegraph, "test3")
      end

      include_examples "sanitized devicegraph"

      it "returns a devicegraph equal to the initial one" do
        expect(subject.sanitized_devicegraph).to eq(devicegraph)
      end
    end
  end
end
