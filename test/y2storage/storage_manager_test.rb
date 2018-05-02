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

  before do
    described_class.create_test_instance
  end

  describe ".new" do
    it "cannot be used directly" do
      expect { described_class.new }.to raise_error(/private method/)
    end
  end

  describe ".setup" do
    context "if the storage instance is not created yet" do
      before do
        described_class.create_test_instance
        described_class.instance_variable_set(:@instance, nil)
      end

      context "and storage system is not locked" do
        before do
          # Mocking #new because it is not possible to create a lock without root privileges
          allow(Storage::Storage).to receive(:new).and_return(storage)
          allow(storage).to receive(:default_mount_by=)
        end

        let(:storage) { instance_double(Storage::Storage) }

        it "creates a new storage instance" do
          expect(Storage::Storage).to receive(:new)
          described_class.setup
        end

        it "returns true" do
          expect(described_class.setup).to eq(true)
        end
      end

      context "and storage system is locked" do
        before do
          allow(Storage::Storage).to receive(:new).and_raise(lock_error)
        end

        let(:lock_error) { Storage::LockException.new(0) }

        context "and the user decides to abort" do
          before do
            allow_any_instance_of(Y2Storage::Callbacks::Initialize).to receive(:retry?)
              .and_return(false)
          end

          it "does not create a new storage instance" do
            described_class.setup
            expect(described_class.instance_variable_get(:@instance)).to be_nil
          end

          it "returns false" do
            expect(described_class.setup).to eq(false)
          end
        end
      end
    end

    context "if the storage instance is already created" do
      before do
        described_class.create_instance(environment)
      end

      let(:environment) do
        Storage::Environment.new(read_only, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
      end

      context "and it can be reused for the requested access mode" do
        let(:read_only) { false }

        let(:mode) { :ro }

        it "does not modify the current storage instance" do
          initial_instance = described_class.instance
          described_class.setup(mode: mode)

          expect(described_class.instance).to equal(initial_instance)
        end

        it "returns true" do
          expect(described_class.setup(mode: mode)).to eq(true)
        end
      end

      context "and it cannot be reused for the requested access mode" do
        let(:read_only) { true }

        let(:mode) { :rw }

        before do
          # To properly test it, the environment should be created with another
          # probe mode, but for that, root privileges are required. So, here we
          # simply mock #test_instance?
          allow(described_class).to receive(:test_instance?).and_return(false)
        end

        it "raises an error" do
          expect { described_class.setup(mode: mode) }.to raise_error(Y2Storage::AccessModeError)
        end
      end
    end
  end

  describe ".instance" do
    before do
      allow(Yast::Mode).to receive(:installation).and_return(installation)
    end

    subject { described_class.instance(mode: mode) }

    let(:installation) { false }

    let(:mode) { :ro }

    context "if the storage instance is not created yet" do
      before do
        described_class.create_test_instance
        described_class.instance_variable_set(:@instance, nil)
      end

      context "and storage system is not locked" do
        before do
          allow_any_instance_of(described_class).to receive(:default_mount_by=)
        end

        shared_examples "creates read-only instance" do
          it "creates a new read-only storage instance" do
            expect(Storage::Storage).to receive(:new) do |environment|
              expect(environment.read_only?).to eq(true)
            end

            subject
          end
        end

        shared_examples "creates read-write instance" do
          it "creates a new read-write storage instance" do
            expect(Storage::Storage).to receive(:new) do |environment|
              expect(environment.read_only?).to eq(false)
            end

            subject
          end
        end

        context "and no specific access mode is requested" do
          let(:mode) { nil }

          context "and it is running during installation" do
            let(:installation) { true }

            include_examples "creates read-write instance"
          end

          context "and it is not running during installation" do
            let(:installation) { false }

            include_examples "creates read-only instance"
          end
        end

        context "and read-only mode is requested" do
          let(:mode) { :ro }

          include_examples "creates read-only instance"
        end

        context "and read-write mode is requested" do
          let(:mode) { :rw }

          include_examples "creates read-write instance"
        end
      end

      context "and storage system is locked" do
        before do
          allow(Storage::Storage).to receive(:new).and_raise(lock_error)
        end

        let(:lock_error) { Storage::LockException.new(0) }

        context "and the user decides to abort" do
          before do
            allow_any_instance_of(Y2Storage::Callbacks::Initialize).to receive(:retry?)
              .and_return(false)
          end

          it "raises an abort exception" do
            expect { subject }.to raise_error(Yast::AbortException)
          end
        end
      end
    end

    context "if the storage instance is already created" do
      before do
        described_class.create_instance(environment)
      end

      let(:environment) do
        Storage::Environment.new(read_only, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
      end

      let(:read_only) { true }

      shared_examples "get current instance" do
        it "returns the current storage instance" do
          initial_instance = described_class.instance
          expect(subject).to equal(initial_instance)
        end
      end

      it "does not try to create a new storage instance" do
        expect(Storage::Storage).to_not receive(:new)
        subject
      end

      context "and no specific access mode is requested" do
        let(:mode) { nil }

        include_examples "get current instance"
      end

      context "and read-only access mode is requested" do
        let(:mode) { :ro }

        context "and the current instance is read-only" do
          let(:read_only) { true }

          include_examples "get current instance"
        end

        context "and the current instance is read-write" do
          let(:read_only) { false }

          include_examples "get current instance"
        end
      end

      context "and read-write access mode is requested" do
        let(:mode) { :rw }

        before do
          # To properly test it, the environment should be created with another
          # probe mode, but for that, root privileges are required. So, here we
          # simply mock #test_instance?
          allow(described_class).to receive(:test_instance?).and_return(false)
        end

        context "and the current instance is read-only" do
          let(:read_only) { true }

          it "raises an error" do
            expect { subject }.to raise_error(Y2Storage::Error)
          end
        end

        context "and the current instance is read-write" do
          let(:read_only) { false }

          include_examples "get current instance"
        end
      end
    end

    it "returns the singleton object in subsequent calls" do
      initial = described_class.create_test_instance
      second = described_class.instance
      # Note using equal to ensure is actually the same object (same object_id)
      expect(second).to equal initial
      expect(described_class.instance).to equal initial
    end

    before do
      allow(Y2Storage::SysconfigStorage.instance).to receive(:default_mount_by)
        .and_return(mount_by_label)
      described_class.create_test_instance
    end

    let(:mount_by_label) { Y2Storage::Filesystems::MountByType::LABEL }

    it "initializes #default_mount_by with the value at sysconfig file" do
      expect(manager.default_mount_by).to eq(mount_by_label)
    end
  end

  describe ".create_instance" do
    context "if the storage system is not locked" do
      before do
        # Mocking #new because it is not possible to create a lock without root privileges
        allow(Storage::Storage).to receive(:new).and_return(storage)
        allow(storage).to receive(:default_mount_by=)
      end

      let(:storage) { instance_double(Storage::Storage) }

      it "creates a new storage instance" do
        initial_instance = described_class.instance
        new_instance = described_class.create_instance

        expect(new_instance).to_not be_nil
        expect(new_instance).to_not equal(initial_instance)
      end
    end

    context "if storage system is locked" do
      before do
        allow(Storage::Storage).to receive(:new).and_raise(lock_error)

        allow(Y2Storage::Callbacks::Initialize).to receive(:new).and_return(callbacks)
        allow(callbacks).to receive(:retry?).and_return(*retry_answers)
      end

      let(:lock_error) { Storage::LockException.new(0) }

      let(:callbacks) { instance_double(Y2Storage::Callbacks::Initialize) }

      context "and the user decides to abort" do
        let(:retry_answers) { [false] }

        it "raises an abort exception" do
          expect { described_class.create_instance }.to raise_error(Yast::AbortException)
        end
      end

      context "and the user decides to retry" do
        let(:retry_answers) { [true, true, false] }

        it "retries the creation of the instance" do
          expect(described_class).to receive(:new).exactly(3).times.and_call_original
          expect { described_class.create_instance }.to raise_error(Yast::AbortException)
        end
      end
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

    it "initializes #storage as not committed" do
      manager = described_class.create_test_instance
      expect(manager.committed?).to be(false)
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

  describe ".fstab_entries" do
    before do
      allow(Storage).to receive(:read_simple_etc_fstab).and_return(storage_entries)
    end

    let(:storage_entries) do
      [
        instance_double(Storage::SimpleEtcFstabEntry),
        instance_double(Storage::SimpleEtcFstabEntry)
      ]
    end

    it "returns a list of fstab entries" do
      expect(described_class.fstab_entries("/etc/fstab")).to all(be_a(Y2Storage::SimpleEtcFstabEntry))
    end

    context "when there is some problem reading the entries" do
      before do
        allow(Storage).to receive(:read_simple_etc_fstab).and_raise(Storage::Exception)
      end

      it "returns an empty list" do
        expect(described_class.fstab_entries("/etc/fstab")).to be_empty
      end
    end
  end

  describe "#default_mount_by" do
    it "returns a MountByType value" do
      expect(manager.default_mount_by).to be_a(Y2Storage::Filesystems::MountByType)
    end
  end

  describe "#default_mount_by=" do
    before do
      allow(Yast::SCR).to receive(:Read) do |path|
        expect(path.to_s).to match(/DEVICE_NAMES/)
      end.and_return("uuid")

      described_class.create_test_instance
    end

    it "updates the default mount_by value" do
      mount_by_id = Y2Storage::Filesystems::MountByType::ID

      expect(manager.default_mount_by).to_not eq(mount_by_id)
      manager.default_mount_by = mount_by_id
      expect(manager.default_mount_by).to eq(mount_by_id)
    end
  end

  describe "#update_sysconfig" do
    before do
      allow(Yast::SCR).to receive(:Write)
    end

    it "stores current default mount_by into sysconfig file" do
      mount_by_label = Y2Storage::Filesystems::MountByType::LABEL
      manager.default_mount_by = mount_by_label

      expect(Yast::SCR).to receive(:Write) do |path, value|
        expect(path.to_s).to match(/storage/)
        expect(value).to eq("label")
      end

      manager.update_sysconfig
    end
  end

  describe "#staging=" do
    let(:old_graph) { devicegraph_from("empty_hard_disk_50GiB") }
    let(:new_graph) { devicegraph_from("gpt_and_msdos") }
    let(:proposal) { double("Y2Storage::GuidedProposal", devices: old_graph) }

    before do
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

    context "when trying to assign staging to itself" do
      # In the past, copying staging into itself, i.e. staging.copy(staging),
      # caused it to become a completely empty devicegraph.
      it "does not modify or break staging" do
        old_staging = manager.staging
        expect(old_staging.disks.size).to eq 1

        manager.staging = old_staging

        expect(manager.staging).to eq old_graph
        expect(manager.staging).to_not be_empty
        expect(manager.staging.disks.size).to eq 1
      end
    end

    it "increments the staging revision" do
      pre = manager.staging_revision
      manager.staging = new_graph
      expect(manager.staging_revision).to be > pre
    end

    it "sets #proposal to nil" do
      expect(manager.proposal).to_not be_nil
      manager.staging = manager.staging
      expect(manager.proposal).to be_nil
    end
  end

  describe "#proposal=" do
    let(:new_graph) { devicegraph_from("gpt_and_msdos") }
    let(:proposal) { double("Y2Storage::GuidedProposal", devices: new_graph) }

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

    it "commits the changes to libstorage passing the corresponding callbacks" do
      expect(manager.storage).to receive(:commit)
        .with(anything, instance_of(Y2Storage::Callbacks::Commit))
      manager.commit
    end

    it "commits the changes to libstorage passing the corresponding options" do
      expect(manager.storage).to receive(:commit) do |options, _callbacks|
        expect(options).to be_a(Storage::CommitOptions)
        expect(options.force_rw).to eq(true)
      end
      manager.commit(force_rw: true)
    end

    it "returns true if everything goes fine" do
      expect(manager.commit).to eq true
    end

    context "if libstorage-ng fails and the user decides to abort" do
      before do
        allow(manager.storage).to receive(:commit).and_raise Storage::Exception
      end

      it "returns false" do
        expect(manager.commit).to eq false
      end
    end

    context "during installation" do
      let(:mode) { :installation }
      let(:staging) { double("Y2Storage::Devicegraph", filesystems: filesystems, to_xml: "xml") }
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

    it "returns true if everything goes fine" do
      expect(manager.probe).to eq true
    end

    context "if libstorage-ng fails and the user decides to abort" do
      before do
        allow(manager.storage).to receive(:probe).and_raise Storage::Exception
      end

      it "returns false" do
        expect(manager.probe).to eq false
      end
    end

    context "if the probed devicegraph needs to be sanitized" do
      let(:st_probed) { devicegraph_from("lvm-errors1-devicegraph.xml").to_storage_value }

      before do
        allow(Y2Storage::Callbacks::Sanitize).to receive(:new).and_return(callbacks)
      end

      let(:callbacks) { instance_double(Y2Storage::Callbacks::Sanitize, sanitize?: sanitize) }

      context "and the user decides to abort" do
        let(:sanitize) { false }

        it "returns false" do
          expect(manager.probe).to eq(false)
        end
      end

      context "and the user devices to continue" do
        let(:sanitize) { true }

        it "returns true" do
          expect(manager.probe).to eq(true)
        end

        it "sanitizes the raw probed devicegraph" do
          manager.probe
          expect(manager.probed.disks).to_not be_empty
          expect(manager.probed.lvm_vgs).to be_empty
        end

        it "copies sanitized probed into staging" do
          manager.probe
          expect(manager.staging).to eq(manager.probed)
        end
      end
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

  describe "#activate" do
    it "starts libstorage-ng activation using the default callbacks" do
      expect(manager.storage).to receive(:activate).with(Y2Storage::Callbacks::Activate)
      manager.activate
    end

    context "when callbacks are given" do
      let(:custom_callbacks) { double("callbacks") }

      it "starts libstorage-ng activation using given callbacks" do
        expect(manager.storage).to receive(:activate).with(custom_callbacks)
        manager.activate(custom_callbacks)
      end
    end

    it "returns true if everything goes fine" do
      expect(manager.activate).to eq true
    end

    context "if libstorage-ng fails and the user decides to abort" do
      before do
        allow(manager.storage).to receive(:activate).and_raise Storage::Exception
      end

      it "returns false" do
        expect(manager.activate).to eq false
      end
    end
  end

  describe "#committed?" do
    before { fake_scenario("gpt_and_msdos") }
    subject(:manager) { described_class.instance }

    context "initially" do
      it "returns false" do
        expect(manager.committed?).to eq false
      end
    end

    context "after reprobing" do
      before { manager.probe_from_yaml(input_file_for("empty_hard_disk_50GiB")) }

      it "returns false" do
        expect(manager.committed?).to eq false
      end
    end

    context "after calling #commit" do
      before do
        allow(manager.storage).to receive(:calculate_actiongraph)
        allow(manager.storage).to receive(:commit)
        manager.commit
      end

      it "returns true" do
        expect(manager.committed?).to eq true
      end

      context "and then reprobing" do
        before { manager.probe_from_yaml(input_file_for("empty_hard_disk_50GiB")) }

        it "returns false" do
          expect(manager.committed?).to eq false
        end
      end
    end
  end

  describe "#mode" do
    subject { described_class.instance }

    before do
      described_class.create_instance(environment)
    end

    let(:environment) do
      Storage::Environment.new(read_only, Storage::ProbeMode_NONE, Storage::TargetMode_DIRECT)
    end

    context "when the instance is created as read-only" do
      let(:read_only) { true }

      it "returns :ro" do
        expect(subject.mode).to eq(:ro)
      end
    end

    context "when the instance is created as read-write" do
      let(:read_only) { false }

      it "returns :rw" do
        expect(subject.mode).to eq(:rw)
      end
    end
  end

  describe "#devices_for_installation?" do
    context "system is already probed" do
      before { fake_scenario("gpt_and_msdos") }
      it "returns true if there is any disk device" do
        expect(subject.devices_for_installation?).to eq true
      end

      it "returns false if there is no local disk device" do
        fake_scenario("nfs1.xml")

        expect(subject.devices_for_installation?).to eq false
      end
    end

    context "system is not yet probed" do
      it "returns result of libstorage method light_probe" do
        expect(::Storage).to receive(:light_probe).and_return true

        expect(subject.devices_for_installation?).to eq true
      end

      it "returns false if libstorage raise exception" do
        expect(::Storage).to receive(:light_probe).and_raise(::Storage::Exception)

        expect(subject.devices_for_installation?).to eq false
      end
    end
  end
end
