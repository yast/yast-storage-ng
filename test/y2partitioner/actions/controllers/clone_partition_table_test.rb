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

require_relative "../../test_helper"
require "y2partitioner/actions/controllers/clone_partition_table"

describe Y2Partitioner::Actions::Controllers::ClonePartitionTable do
  before do
    devicegraph_stub(scenario)
  end

  subject(:controller) { described_class.new(device) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:scenario) { "mixed_disks_clone.yml" }

  describe "#initialize" do
    context "when the given device is a partitionable device" do
      let(:device_name) { "/dev/sda" }

      it "does not raise an exception" do
        expect { described_class.new(device) }.to_not raise_error
      end
    end

    context "when the given device is not a partitionable device" do
      let(:device_name) { "/dev/sda1" }

      it "raises an exception" do
        expect { described_class.new(device) }.to raise_error(TypeError)
      end
    end
  end

  describe "#partition_table?" do
    context "when the current device has no partition table" do
      let(:device_name) { "/dev/sdd" }

      it "returns false" do
        expect(subject.partition_table?).to eq(false)
      end
    end

    context "when the current device has partition table" do
      let(:device_name) { "/dev/sda" }

      it "returns true" do
        expect(subject.partition_table?).to eq(true)
      end
    end
  end

  describe "#suitable_devices_for_cloning?" do
    context "when there are no suitable devices for cloning the current device" do
      let(:device_name) { "/dev/sdb" }

      it "returns false" do
        expect(subject.suitable_devices_for_cloning?).to eq(false)
      end
    end

    context "when there are suitable devices for cloning the current device" do
      let(:device_name) { "/dev/sda" }

      it "returns true" do
        expect(subject.suitable_devices_for_cloning?).to eq(true)
      end
    end
  end

  describe "#suitable_devices_for_cloning" do
    before do
      allow(Yast::Mode).to receive(:installation).and_return(installation)
    end

    let(:installation) { true }

    context "when there are no suitable devices for cloning the current device" do
      let(:device_name) { "/dev/sdb" }

      it "returns an empty list" do
        expect(subject.suitable_devices_for_cloning).to be_empty
      end
    end

    context "when there are suitable devices for cloning the current device" do
      let(:device_name) { "/dev/sda" }

      it "returns a list of suitable devices for cloning" do
        expect(subject.suitable_devices_for_cloning).to_not be_empty
        expect(subject.suitable_devices_for_cloning.map(&:name))
          .to include("/dev/sdb", "/dev/sdc", "/dev/sdd", "/dev/dasdb")
      end

      it "does not include itself" do
        expect(subject.suitable_devices_for_cloning.map(&:name)).to_not include("/dev/sda")
      end

      it "does not include devices without enough size" do
        expect(subject.suitable_devices_for_cloning.map(&:name)).to_not include("/dev/sde")
      end

      it "does not include devices with a different topology" do
        expect(subject.suitable_devices_for_cloning.map(&:name)).to_not include("/dev/dasda")
      end

      context "when some devices do not support the partition table type" do
        let(:device_name) { "/dev/dasda" }

        it "does not include devices without support for the partition table type" do
          expect(subject.suitable_devices_for_cloning.map(&:name))
            .to_not include("/dev/sdb", "/dev/sdc", "/dev/sdd")
        end
      end

      context "when it is not running in installation mode" do
        let(:installation) { false }

        it "does not include devices with mount points" do
          expect(subject.suitable_devices_for_cloning.map(&:name)).to_not include("/dev/sdb")
        end
      end
    end
  end

  describe "#clone_to_device" do
    let(:device_name) { "/dev/sda" }

    let(:sdc) { current_graph.find_by_name("/dev/sdc") }

    it "removes previous partition table" do
      expect(sdc.partition_table.type).to eq(Y2Storage::PartitionTables::Type::GPT)

      subject.clone_to_device(sdc)

      expect(device.partition_table.type).to eq(Y2Storage::PartitionTables::Type::MSDOS)
      expect(sdc.partition_table.type).to eq(Y2Storage::PartitionTables::Type::MSDOS)
    end

    it "copies all partitions" do
      subject.clone_to_device(sdc)

      device_partitions = device.partitions.sort_by(&:name)
      sdc_partitions = sdc.partitions.sort_by(&:name)

      expect(device_partitions.map(&:region)).to eq(sdc_partitions.map(&:region))
      expect(device_partitions.map(&:id)).to eq(sdc_partitions.map(&:id))
    end

    it "does not copy encryptions" do
      subject.clone_to_device(sdc)

      expect(device.partitions.map(&:encrypted?)).to include(true)
      expect(sdc.partitions.map(&:encrypted?)).to all(be false)
    end

    it "does not copy filesystems" do
      subject.clone_to_device(sdc)

      expect(device.partitions.map { |p| !p.filesystem.nil? }).to include(true)
      expect(sdc.partitions.map(&:filesystem)).to all(be nil)
    end
  end
end
