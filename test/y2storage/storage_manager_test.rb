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
  storage = Y2Storage::StorageManager.instance.storage
  st_graph = Storage::Devicegraph.new(storage)
  graph = Y2Storage::Devicegraph.new(st_graph)
  yaml_file = input_file_for(file_name)
  Y2Storage::FakeDeviceFactory.load_yaml_file(graph, yaml_file)
  graph
end

describe Y2Storage::StorageManager do

  subject(:manager) { described_class.instance }

  describe ".new" do
    it "cannot be used directly" do
      expect { described_class.new }.to raise_error(/private method/)
    end
  end

  describe ".create_test_instance" do
    it "returns the singleton StorageManager object" do
      expect(described_class.create_test_instance).to be_a described_class
    end

    it "initializes #storage as not probed" do
      manager = described_class.create_test_instance
      expect(manager.probed?).to be(false)
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
    let(:proposal) { double("Y2Storage::GuidedProposal", devices: old_graph) }

    before do
      described_class.create_test_instance
      manager.proposal = proposal
    end

    it "copies the provided devicegraph to staging" do
      expect(manager.staging).to eq old_graph
      manager.staging = new_graph
      expect(Y2Storage::Disk.all(manager.staging).size).to eq 6
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
    let(:proposal) { double("Y2Storage::GuidedProposal", devices: new_graph) }

    before do
      described_class.create_test_instance
    end

    it "copies the proposal result to staging" do
      manager.proposal = proposal
      expect(Y2Storage::Disk.all(manager.staging).size).to eq 6
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
    let(:proposal) { double("Y2Storage::GuidedProposal", devices: new_graph) }

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
      allow(Yast::Mode).to receive(:installation).and_return(mode == :installation)
      allow(Yast::Stage).to receive(:initial).and_return(mode == :installation)
    end

    let(:mode) { :normal }

    it "delegates calculation of the needed actions to libstorage" do
      expect(manager.storage).to receive(:calculate_actiongraph)
      manager.commit
    end

    it "commits the changes to libstorage" do
      expect(manager.storage).to receive(:commit)
      manager.commit
    end

    context "during installation" do
      let(:mode) { :installation }
      let(:staging) { double("Y2Storage::Devicegraph", filesystems: filesystems) }
      let(:filesystems) { [root_fs, another_fs] }
      let(:root_fs) { double("Y2Storage::BlkFilesystem", root?: true) }
      let(:another_fs) { double("Y2Storage::BlkFilesystem", root?: false) }

      before do
        allow(manager).to receive(:staging).and_return staging
      end

      context "if the root filesystem does not respond to #configure_snapper" do
        it "sets FsSnapshot.configure_on_install? to false" do
          manager.commit
          expect(Yast2::FsSnapshot.configure_on_install?).to eq false
        end
      end

      context "if the root filesystem is set to configure snapper" do
        before { allow(root_fs).to receive(:configure_snapper).and_return true }

        it "sets FsSnapshot.configure_on_install? to true" do
          manager.commit
          expect(Yast2::FsSnapshot.configure_on_install?).to eq true
        end
      end

      context "if the root filesystem is set to not configure snapper" do
        before { allow(root_fs).to receive(:configure_snapper).and_return false }

        it "sets FsSnapshot.configure_on_install? to false" do
          manager.commit
          expect(Yast2::FsSnapshot.configure_on_install?).to eq false
        end
      end

      context "if there is no root filesystem" do
        let(:filesystems) { [another_fs] }

        it "sets FsSnapshot.configure_on_install? to false" do
          manager.commit
          expect(Yast2::FsSnapshot.configure_on_install?).to eq false
        end
      end
    end

    context "in normal mode" do
      let(:mode) { :normal }

      it "sets FsSnapshot.configure_on_install? to false" do
        manager.commit
        expect(Yast2::FsSnapshot.configure_on_install?).to eq false
      end
    end
  end

  describe "#probe" do
    before do
      described_class.instance.probe_from_yaml(input_file_for("gpt_and_msdos"))
      # Ensure old values have been queried at least once
      manager.probed
      manager.probed_disk_analyzer
      manager.staging
      manager.proposal

      # And now mock subsequent Storage calls
      allow(manager.storage).to receive(:probe)
      allow(manager.storage).to receive(:probed).and_return st_probed
      allow(manager.storage).to receive(:staging).and_return st_staging
    end

    let(:st_probed) { Storage::Devicegraph.new(manager.storage) }
    let(:st_staging) { Storage::Devicegraph.new(manager.storage) }
    let(:devicegraph) { Y2Storage::Devicegraph.new(st_staging) }
    let(:proposal) { double("Y2Storage::GuidedProposal", devices: devicegraph) }

    it "refreshes #probed" do
      expect(manager.probed.disks.size).to eq 6
      # Calling twice (or more) does not result in a refresh
      expect(manager.probed.disks.size).to eq 6
      expect(manager.probed.to_storage_value).to_not eq st_probed

      manager.probe

      expect(manager.probed.disks.size).to eq 0
      expect(manager.probed.to_storage_value).to eq st_probed
    end

    it "refreshes #staging" do
      expect(manager.probed.disks.size).to eq 6
      # Calling twice (or more) does not result in a refresh
      expect(manager.probed.disks.size).to eq 6
      expect(manager.probed.to_storage_value).to_not eq st_staging

      manager.probe

      expect(manager.probed.disks.size).to eq 0
      expect(manager.probed.to_storage_value).to eq st_staging
    end

    it "increments the staging revision" do
      pre = manager.staging_revision
      manager.probe
      expect(manager.staging_revision).to be > pre
    end

    it "refreshes #probed_disk_analyzer" do
      pre = manager.probed_disk_analyzer
      # Calling twice (or more) does not result in a refresh
      expect(manager.probed_disk_analyzer).to eq pre

      manager.probe
      expect(manager.probed_disk_analyzer).to_not eq pre
    end

    it "sets #proposal to nil" do
      manager.proposal = proposal
      manager.probe
      expect(manager.proposal).to be_nil
    end
  end

  describe "#probe_from_yaml" do
    let(:st_devicegraph) { Storage::Devicegraph.new(manager.storage) }
    let(:devicegraph) { Y2Storage::Devicegraph.new(st_devicegraph) }
    let(:proposal) { double("Y2Storage::GuidedProposal", devices: devicegraph) }

    it "refreshes #probed" do
      manager = described_class.create_test_instance
      expect(manager.probed).to be_empty

      manager.probe_from_yaml(input_file_for("gpt_and_msdos"))

      expect(manager.probed).to_not be_empty
      expect(manager.probed.disks.size).to eq 6
    end

    it "refreshes #staging" do
      manager = described_class.create_test_instance
      expect(manager.staging).to be_empty

      manager.probe_from_yaml(input_file_for("gpt_and_msdos"))

      expect(manager.staging).to_not be_empty
      expect(manager.staging.disks.size).to eq 6
    end

    it "increments the staging revision" do
      pre = manager.staging_revision
      manager.probe_from_yaml(input_file_for("gpt_and_msdos"))
      expect(manager.staging_revision).to be > pre
    end

    it "refreshes #probed_disk_analyzer" do
      pre = manager.probed_disk_analyzer
      # Calling twice (or more) does not result in a refresh
      expect(manager.probed_disk_analyzer).to eq pre

      manager.probe_from_yaml(input_file_for("gpt_and_msdos"))
      expect(manager.probed_disk_analyzer).to_not eq pre
    end

    it "sets #proposal to nil" do
      manager.proposal = proposal
      manager.probe_from_yaml(input_file_for("gpt_and_msdos"))
      expect(manager.proposal).to be_nil
    end
  end

  describe "#probe_from_xml" do
    let(:st_devicegraph) { Storage::Devicegraph.new(manager.storage) }
    let(:devicegraph) { Y2Storage::Devicegraph.new(st_devicegraph) }
    let(:proposal) { double("Y2Storage::GuidedProposal", devices: devicegraph) }

    it "refreshes #probed" do
      manager = described_class.create_test_instance
      expect(manager.probed).to be_empty

      manager.probe_from_xml(input_file_for("md2-devicegraph", suffix: "xml"))

      expect(manager.probed).to_not be_empty
      expect(manager.probed.disks.size).to eq 4
    end

    it "refreshes #staging" do
      manager = described_class.create_test_instance
      expect(manager.staging).to be_empty

      manager.probe_from_xml(input_file_for("md2-devicegraph", suffix: "xml"))

      expect(manager.staging).to_not be_empty
      expect(manager.staging.disks.size).to eq 4
    end

    it "increments the staging revision" do
      pre = manager.staging_revision
      manager.probe_from_xml(input_file_for("md2-devicegraph", suffix: "xml"))
      expect(manager.staging_revision).to be > pre
    end

    it "refreshes #probed_disk_analyzer" do
      pre = manager.probed_disk_analyzer
      # Calling twice (or more) does not result in a refresh
      expect(manager.probed_disk_analyzer).to eq pre

      manager.probe_from_xml(input_file_for("md2-devicegraph", suffix: "xml"))
      expect(manager.probed_disk_analyzer).to_not eq pre
    end

    it "sets #proposal to nil" do
      manager.proposal = proposal
      manager.probe_from_xml(input_file_for("md2-devicegraph", suffix: "xml"))
      expect(manager.proposal).to be_nil
    end
  end
end
