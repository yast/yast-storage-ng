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

describe Y2Storage::StorageManager do

  subject(:manager) { described_class.instance }

  describe ".new" do
    it "cannot be used directly" do
      expect { described_class.new }.to raise_error
    end
  end

  describe ".create_test_instance" do
    it "returns the singleton StorageManager object" do
      expect(described_class.create_test_instance).to be_a described_class
    end

    it "initializes #storage with empty devicegraphs" do
      manager = described_class.create_test_instance
      expect(manager.storage).to be_a Storage::Storage
      expect(manager.probed).to be_empty
      expect(manager.staging).to be_empty
    end

    it "initializes #staging_revision" do
      manager = described_class.create_test_instance
      expect(manager.staging_revision).to be_zero
    end
  end

  describe ".fake_from_yaml" do
    it "returns the singleton StorageManager object" do
      result = described_class.fake_from_yaml(input_file_for("gpt_and_msdos"))
      expect(result).to be_a described_class
    end

    it "initializes #storage with the mocked devicegraphs" do
      manager = described_class.fake_from_yaml(input_file_for("gpt_and_msdos"))
      expect(manager.storage).to be_a Storage::Storage
      expect(Storage::Disk.all(manager.probed).size).to eq 6
      expect(Storage::Disk.all(manager.staging).size).to eq 6
    end

    it "initializes #staging_revision" do
      manager = described_class.create_test_instance
      expect(manager.staging_revision).to be_zero
    end
  end

  describe ".instance" do
    it "returns the singleton object in subsequent calls" do
      initial = described_class.create_test_instance
      second = described_class.instance
      # Note using equal to ensure is actually the same object (same object_id)
      expect(second).to equal initial
      expect(described_class.instance).to equal initial
    end
  end

  describe "#copy_to_staging" do
    before do
      described_class.create_test_instance
    end

    let(:new_graph) do
      new_graph = Storage::Devicegraph.new
      yaml_file = input_file_for("gpt_and_msdos")
      Y2Storage::FakeDeviceFactory.load_yaml_file(new_graph, yaml_file)
      new_graph
    end

    it "copies the devicegraph" do
      expect(manager.staging).to be_empty
      manager.copy_to_staging(new_graph)
      expect(Storage::Disk.all(manager.staging).size).to eq 6
    end

    it "increments the staging revision" do
      pre = manager.staging_revision
      manager.copy_to_staging(new_graph)
      expect(manager.staging_revision).to be > pre
    end
  end
end
