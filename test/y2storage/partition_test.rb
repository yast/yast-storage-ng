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

require_relative "spec_helper"
require "y2storage"

describe Y2Storage::Partition do
  before do
    fake_scenario(scenario)
  end
  let(:scenario) { "autoyast_drive_examples" }

  describe ".all" do
    it "returns a list of Y2Storage::Partition objects" do
      partitions = Y2Storage::Partition.all(fake_devicegraph)
      expect(partitions).to be_an Array
      expect(partitions).to all(be_a(Y2Storage::Partition))
    end

    it "includes all primary, extended and logical partitions in the devicegraph" do
      partitions = Y2Storage::Partition.all(fake_devicegraph)
      expect(partitions.map(&:basename)).to contain_exactly(
        "sdb1", "sdb2", "dasdb1", "dasdb2", "dasdb3", "sdc1", "sdc2", "sdc3", "sdd1",
        "sdd2", "sdd3", "sdd4", "sdd5", "sdd6", "sde1", "sde2", "sde3", "sdf1", "sdf2",
        "sdf5", "sdf6", "sdf7", "sdg1", "sdg2", "sdg3", "sdg4", "sdh1", "sdh2", "sdh3"
      )
    end
  end

  describe "#adapted_id=" do
    subject(:partition) { Y2Storage::Partition.find_by_name(fake_devicegraph, "/dev/sdb1") }

    let(:swap) { Y2Storage::PartitionId::SWAP }
    let(:linux) { Y2Storage::PartitionId::LINUX }
    let(:win_data) { Y2Storage::PartitionId::WINDOWS_BASIC_DATA }

    let(:partition_table) { double("PartitionTable") }
    before { allow(partition).to receive(:partition_table).and_return partition_table }

    it "relies on PartitionTable#partition_id_for to adapt the id" do
      expect(partition_table).to receive(:partition_id_for).with(swap).and_return linux
      partition.adapted_id = swap
    end

    context "if libstorage-ng accepts the adapted id" do
      before do
        allow(partition_table).to receive(:partition_id_for).and_return swap
      end

      it "sets the id to the adapted one" do
        partition.adapted_id = linux
        expect(partition.id).to eq swap
      end
    end

    context "if libstorage-ng rejects the adapted id with an exception" do
      before do
        allow(partition_table).to receive(:partition_id_for).and_return win_data
      end

      it "does not propagate the exception" do
        expect { partition.adapted_id = swap }.to_not raise_error
      end

      it "sets the id always to LINUX" do
        partition.adapted_id = swap
        expect(partition.id).to eq linux
      end
    end

    context "if a different exception is raised in the process" do
      before do
        allow(partition_table).to receive(:partition_id_for).and_raise ArgumentError
      end

      it "propagates the exception" do
        expect { partition.adapted_id = swap }.to raise_error ArgumentError
      end
    end
  end
end
