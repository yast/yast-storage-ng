#!/usr/bin/env rspec
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

      it "returns a list of errors" do
        errors = subject.errors

        expect(errors).to be_a(Array)
        expect(errors).to all(be_a(Y2Storage::DevicegraphSanitizer::Error))
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

    context "when there are LVM VGs in the devicegraph" do
      let(:devicegraph) { devicegraph_from("lvm-errors1-devicegraph.xml") }

      before do
        Y2Storage::LvmVg.create(devicegraph, "test3")
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
    end

    context "when there is a bcache device in the devicegraph" do
      let(:devicegraph) { devicegraph_from("bcache2.xml") }

      before do
        # Unmocking errors for Bcache (see spec_helper.rb)
        allow_any_instance_of(Y2Storage::DevicegraphSanitizer)
          .to receive(:bcaches_errors).and_call_original
      end

      context "on an architecture that supports bcache (x86_64)" do
        let(:architecture) { :x86_64 }

        it "does not contain an error" do
          expect(subject.errors).to be_empty
        end
      end

      context "on an architecture that does not support bcache (ppc)" do
        let(:architecture) { :ppc }

        it "contains a bcache-related error" do
          errors = subject.errors
          expect(errors).not_to be_empty

          expect(errors).to include(be_a(Y2Storage::DevicegraphSanitizer::UnsupportedBcacheError))
        end
      end
    end

    context "when the mount point for the root filesystem is not active" do
      let(:devicegraph) { devicegraph_from("mixed_disks") }

      before do
        allow_any_instance_of(Y2Storage::MountPoint).to receive(:active?).and_return(false)
      end

      it "contains an error for inactive root" do
        errors = subject.errors
        expect(errors).not_to be_empty

        expect(errors).to include(be_a(Y2Storage::DevicegraphSanitizer::InactiveRootError))
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

      include_examples "sanitized devicegraph"

      context "when there are LVM VGS with missing PVs" do
        let(:devicegraph) { devicegraph_from("lvm-errors1-devicegraph.xml") }

        before do
          Y2Storage::LvmVg.create(devicegraph, "test3")
        end

        it "returns a devicegraph without the LVM VGs with missing PVs" do
          vg3 = devicegraph.find_by_name("/dev/test3")

          expect(devicegraph.lvm_vgs.size).to eq(3)
          expect(subject.sanitized_devicegraph.lvm_vgs).to contain_exactly(vg3)
        end
      end

      context "when there is a Bcache device in a not supported architecture" do
        let(:devicegraph) { devicegraph_from("bcache2.xml") }

        before do
          # Unmocking errors for Bcache (see spec_helper.rb)
          allow_any_instance_of(Y2Storage::DevicegraphSanitizer)
            .to receive(:bcaches_errors).and_call_original
        end

        let(:architecture) { :ppc }

        it "returns a devicegraph equal to the initial one" do
          expect(subject.sanitized_devicegraph).to eq(devicegraph)
        end
      end

      context "when there is an inactive root" do
        let(:devicegraph) { devicegraph_from("mixed_disks") }

        before do
          allow_any_instance_of(Y2Storage::MountPoint).to receive(:active?).and_return(false)
        end

        it "returns a devicegraph equal to the initial one" do
          expect(subject.sanitized_devicegraph).to eq(devicegraph)
        end
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

  describe Y2Storage::DevicegraphSanitizer::MissingLvmPvError do
    let(:devicegraph) { devicegraph_from(scenario) }

    describe ".check" do
      let(:scenario) { "lvm-errors1-devicegraph.xml" }

      let(:device) { devicegraph.find_by_name(device_name) }

      context "when the given device is a LVM VG with missing PVs" do
        let(:device_name) { "/dev/test1" }

        it "returns true" do
          expect(described_class.check(device)).to eq(true)
        end
      end

      context "when the given device is a LVM VG without missing PVs" do
        before do
          Y2Storage::LvmVg.create(devicegraph, "test3")
        end

        let(:device_name) { "/dev/test3" }

        it "returns false" do
          expect(described_class.check(device)).to eq(false)
        end
      end
    end

    describe "#message" do
      subject { described_class.new(device) }

      let(:scenario) { "lvm-errors1-devicegraph.xml" }

      let(:device) { devicegraph.find_by_name("/dev/test1") }

      it "returns a message for incomplete LVM VG" do
        expect(subject.message).to match("volume group /dev/test1 is incomplete")
      end
    end

    describe "#fix" do
      subject { described_class.new(device) }

      let(:scenario) { "lvm-errors1-devicegraph.xml" }

      let(:device) { devicegraph.find_by_name("/dev/test1") }

      it "removes the LVM VGs with missing PVs" do
        expect(devicegraph.find_by_name("/dev/test1")).to_not be_nil

        subject.fix(devicegraph)

        expect(devicegraph.find_by_name("/dev/test1")).to be_nil
      end
    end
  end

  describe Y2Storage::DevicegraphSanitizer::UnsupportedBcacheError do
    let(:devicegraph) { devicegraph_from(scenario) }

    describe ".check" do
      context "when Bcache is not supported by the current architecture" do
        let(:architecture) { :ppc }

        context "and there are Bcache devices" do
          let(:scenario) { "bcache2.xml" }

          it "returns true" do
            expect(described_class.check(devicegraph)).to eq(true)
          end
        end

        context "and there are no Bcache devices" do
          let(:scenario) { "mixed_disks" }

          it "returns false" do
            expect(described_class.check(devicegraph)).to eq(false)
          end
        end
      end

      context "when Bcache is supported by the current architecture" do
        let(:architecture) { :x86_64 }

        let(:scenario) { "bcache2.xml" }

        it "returns false" do
          expect(described_class.check(devicegraph)).to eq(false)
        end
      end
    end

    describe "#message" do
      subject { described_class.new }

      let(:scenario) { "bcache2.xml" }

      it "returns a message for unsupported Bcache device" do
        expect(subject.message).to match("bcache is not supported")
      end
    end

    describe "#fix" do
      subject { described_class.new }

      let(:scenario) { "bcache2.xml" }

      it "does not modify the given devicegraph" do
        init_devicegraph = devicegraph.dup

        subject.fix(devicegraph)

        expect(devicegraph).to eq(init_devicegraph)
      end
    end
  end

  describe Y2Storage::DevicegraphSanitizer::InactiveRootError do
    let(:devicegraph) { devicegraph_from(scenario) }

    let(:scenario) { "mixed_disks" }

    let(:device) { devicegraph.find_by_name(device_name) }

    let(:filesystem) { device.filesystem }

    describe ".check" do
      context "when the given filesystem is not root" do
        let(:device_name) { "/dev/sdb5" }

        it "returns false" do
          expect(described_class.check(filesystem)).to eq(false)
        end
      end

      context "when the given filesystem is root" do
        let(:device_name) { "/dev/sdb2" }

        before do
          device.mount_point.active = active
        end

        context "and its mount point is active" do
          let(:active) { true }

          it "returns false" do
            expect(described_class.check(filesystem)).to eq(false)
          end
        end

        context "and its mount point is not active" do
          let(:active) { false }

          it "returns true" do
            expect(described_class.check(filesystem)).to eq(true)
          end
        end
      end
    end

    describe "#message" do
      subject { described_class.new(filesystem) }

      let(:device_name) { "/dev/sdb2" }

      it "returns a message for inactive root" do
        expect(subject.message).to match("root filesystem looks like not currently mounted")
      end

      context "and the filesystem is Btrfs" do
        it "includes rollback tip" do
          expect(subject.message).to match("executed a snapshot rollback")
        end
      end
    end

    describe "#fix" do
      subject { described_class.new(filesystem) }

      let(:device_name) { "/dev/sdb2" }

      it "does not modify the given devicegraph" do
        init_devicegraph = devicegraph.dup

        subject.fix(devicegraph)

        expect(devicegraph).to eq(init_devicegraph)
      end
    end
  end
end
