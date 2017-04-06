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

def devicegraph_from(file_name)
  st_graph = Storage::Devicegraph.new
  graph = Y2Storage::Devicegraph.new(st_graph)
  yaml_file = input_file_for(file_name)
  Y2Storage::FakeDeviceFactory.load_yaml_file(graph, yaml_file)
  graph
end

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

  describe "#staging=" do
    let(:old_graph) { devicegraph_from("empty_hard_disk_50GiB") }
    let(:new_graph) { devicegraph_from("gpt_and_msdos") }
    let(:proposal) { double("Y2Storage::Proposal", devices: old_graph) }

    before do
      described_class.create_test_instance
      manager.proposal = proposal
    end

    it "copies the provided devicegraph to staging" do
      expect(manager.y2storage_staging).to eq old_graph
      manager.staging = new_graph
      expect(Storage::Disk.all(manager.staging).size).to eq 6
    end

    it "increments the staging revision" do
      pre = manager.staging_revision
      manager.staging = new_graph
      expect(manager.staging_revision).to be > pre
    end

    it "sets #proposal to nil" do
      expect(manager.proposal).to_not be_nil
      manager.staging = new_graph
      expect(manager.proposal).to be_nil
    end
  end

  describe "#proposal=" do
    let(:new_graph) { devicegraph_from("gpt_and_msdos") }
    let(:proposal) { double("Y2Storage::Proposal", devices: new_graph) }

    before do
      described_class.create_test_instance
    end

    it "copies the proposal result to staging" do
      manager.proposal = proposal
      expect(Storage::Disk.all(manager.staging).size).to eq 6
    end

    it "increments the staging revision" do
      pre = manager.staging_revision
      manager.proposal = proposal
      expect(manager.staging_revision).to be > pre
    end

    it "stores the proposal" do
      manager.proposal = proposal
      expect(manager.proposal).to eq proposal
    end
  end

  describe "#staging_changed?" do
    let(:new_graph) { devicegraph_from("gpt_and_msdos") }
    let(:proposal) { double("Y2Storage::Proposal", devices: new_graph) }

    before do
      described_class.create_test_instance
    end

    it "returns false initially" do
      expect(manager.staging_changed?).to eq false
    end

    it "returns true if the staging devicegraph was manually assigned" do
      manager.staging = new_graph
      expect(manager.staging_changed?).to eq true
    end

    it "returns true if a proposal was accepted" do
      manager.proposal = proposal
      expect(manager.staging_changed?).to eq true
    end
  end

  describe "#rootprefix=" do
    before do
      described_class.create_test_instance
    end

    it "updates the rootprefix value in the instance" do
      manager.rootprefix = "something"
      expect(manager.rootprefix).to eq "something"
    end

    it "updates the rootprefix value in libstorage" do
      manager.rootprefix = "something"
      storage = described_class.instance.storage
      expect(storage.rootprefix).to eq "something"
    end
  end

  describe "#prepend_rootprefix" do
    before do
      described_class.create_test_instance
    end

    it "returns the same string if a prefix is not set for libstorage" do
      expect(manager.prepend_rootprefix("/absolute/path")).to eq "/absolute/path"
    end

    it "prepends the libstorage prefix to the provided path" do
      manager.rootprefix = "/prefixed"
      expect(manager.prepend_rootprefix("/absolute/path")).to eq "/prefixed/absolute/path"
    end

    it "does not add any missing slash" do
      manager.rootprefix = "pre"
      expect(manager.prepend_rootprefix("absolute/path")).to eq "preabsolute/path"
    end

    it "does not remove any trailing slash" do
      manager.rootprefix = "/prefixed/"
      expect(manager.prepend_rootprefix("/absolute///path/")).to eq "/prefixed//absolute///path/"
    end
  end

  describe "#commit" do
    before do
      described_class.create_test_instance
      allow(manager.storage).to receive(:calculate_actiongraph)
      allow(manager.storage).to receive(:commit)
    end

    it "delegates calculation of the needed actions to libstorage" do
      expect(manager.storage).to receive(:calculate_actiongraph)
      manager.commit
    end

    it "commits the changes to libstorage" do
      expect(manager.storage).to receive(:commit)
      manager.commit
    end
  end
end
