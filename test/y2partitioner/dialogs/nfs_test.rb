#!/usr/bin/env rspec
# Copyright (c) [2022] SUSE LLC
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

require_relative "../test_helper"

require "cwm/rspec"
require "y2storage"
require "y2partitioner/dialogs/nfs"

# Namespace typically used for classes coming from yast2-nfs-client
module Y2NfsClient
  # yast2-nfs-client equivalent for Y2Partitioner::Widgets
  module Widgets
  end
end

describe Y2Partitioner::Dialogs::Nfs do
  before do
    devicegraph_stub("nfs1.xml")

    allow(described_class).to receive(:require).and_call_original
    allow(described_class).to receive(:require).with("y2nfs_client/widgets/nfs_form") do
      raise LoadError, "cannot load such file" unless nfs_form_class_name

      define_nfs_form_class
    end
  end

  after do
    Y2NfsClient::Widgets.send(:remove_const, nfs_form_class_name) if nfs_form_class_name
  end

  let(:nfs_form_class_name) { "NfsForm" }

  # Defines a fake class to stub the form defined at yast2-nfs-client
  def define_nfs_form_class
    c = Class.new do
      attr_reader :nfs

      # Constructor of the fake class
      def initialize(nfs, entries)
        @nfs = nfs
        @entries = entries
      end
    end

    Y2NfsClient::Widgets.const_set(nfs_form_class_name, c)
  end

  let(:legacy_nfs) { Y2Storage::Filesystems::LegacyNfs.new }
  let(:entries) { [] }
  subject(:dialog) { described_class.new(legacy_nfs, entries) }

  include_examples "CWM::Dialog"

  describe ".run?" do
    before do
      allow(Yast::Stage).to receive(:initial).and_return in_installation
    end

    context "during installation" do
      let(:in_installation) { true }
      let(:nfs_form_class_name) { "NfsForm" }

      RSpec.shared_examples "don't install nfs-client" do
        it "does not try to install any package" do
          expect(Yast::Package).to_not receive(:CheckAndInstallPackages)
          described_class.run?
        end
      end

      context "if the file of the y2-nfs-client form is available and defines the expected class" do
        let(:nfs_form_class_name) { "NfsForm" }

        include_examples "don't install nfs-client"

        it "returns true" do
          expect(described_class.run?).to eq true
        end
      end

      context "if the file of the y2-nfs-client form is available but defines a wrong class" do
        let(:nfs_form_class_name) { "NfsWidget" }

        include_examples "don't install nfs-client"

        it "returns false" do
          expect(described_class.run?).to eq false
        end
      end

      context "if the file of the y2-nfs-client form is not found" do
        let(:nfs_form_class_name) { nil }

        include_examples "don't install nfs-client"

        it "returns false" do
          expect(described_class.run?).to eq false
        end
      end
    end

    context "in an installed system" do
      let(:in_installation) { false }

      before do
        allow(Yast::PackageCallbacks).to receive(:RegisterEmptyProgressCallbacks)
        allow(Yast::PackageCallbacks).to receive(:RestorePreviousProgressCallbacks)
      end

      RSpec.shared_examples "try to install nfs-client" do
        it "tries to install yast2-nfs-client" do
          expect(Yast::Package).to receive(:CheckAndInstallPackages)
            .with(["yast2-nfs-client"])
          described_class.run?
        end

        context "and the installation of yast2-nfs-client succeeds" do
          before do
            allow(Yast::Package).to receive(:CheckAndInstallPackages).and_return true

            it "returns true (whithout checking whether the expected class becomes available)" do
              expect(described_class.run?).to eq true
            end
          end
        end

        context "and it fails to install yast2-nfs-client" do
          before do
            allow(Yast::Package).to receive(:CheckAndInstallPackages).and_return false

            it "returns false" do
              expect(described_class.run?).to eq false
            end
          end
        end
      end

      context "if the file of the y2-nfs-client form is available and defines the expected class" do
        let(:nfs_form_class_name) { "NfsForm" }

        include_examples "don't install nfs-client"

        it "does not try to install any package" do
          expect(Yast::Package).to_not receive(:CheckAndInstallPackages)
          described_class.run?
        end

        it "returns true" do
          expect(described_class.run?).to eq true
        end
      end

      context "if the file of the y2-nfs-client form is available but defines a wrong class" do
        let(:nfs_form_class_name) { "NfsWidget" }

        include_examples "try to install nfs-client"
      end

      context "if the file of the y2-nfs-client form is not found" do
        let(:nfs_form_class_name) { nil }
        include_examples "try to install nfs-client"
      end
    end
  end

  describe "#title" do
    context "when called for a new NFS mount" do
      let(:legacy_nfs) { Y2Storage::Filesystems::LegacyNfs.new }

      it "includes the word 'add'" do
        expect(dialog.title).to start_with "Add"
      end
    end

    context "when called for a pre-existing NFS mount" do
      let(:nfs) { fake_devicegraph.nfs_mounts.first }
      let(:legacy_nfs) { Y2Storage::Filesystems::LegacyNfs.new_from_nfs(nfs) }

      it "includes the word 'edit'" do
        expect(dialog.title).to start_with "Edit"
      end
    end
  end

  describe Y2Partitioner::Dialogs::Nfs::FormValidator do
    subject { described_class.new(nfs_form) }

    let(:nfs) { fake_devicegraph.nfs_mounts.first }
    let(:legacy_nfs) { Y2Storage::Filesystems::LegacyNfs.new_from_nfs(nfs) }

    describe "#validate" do
      before do
        allow(legacy_nfs).to receive(:reachable?).and_return reachable

        define_nfs_form_class
        allow(Y2NfsClient::Widgets::NfsForm).to receive(:new).and_return nfs_form

        allow(nfs_form).to receive(:store) do
          legacy_nfs.server = new_server
          legacy_nfs.path = new_remote_path
        end
      end

      let(:nfs_form) { double(Y2NfsClient::Widgets::NfsForm, nfs: legacy_nfs) }

      context "when the connection information has not changed" do
        let(:new_server) { legacy_nfs.server }
        let(:new_remote_path) { legacy_nfs.path }

        context "and the NFS share is accessible" do
          let(:reachable) { true }

          it "does not ask for any extra confirmation" do
            expect(Yast::Popup).to_not receive(:YesNo)
          end

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end

        context "and the NFS share is not accessible" do
          let(:reachable) { false }

          it "does not ask for any extra confirmation" do
            expect(Yast::Popup).to_not receive(:YesNo)
          end

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end
      end

      context "when the connection information has changed" do
        let(:new_server) { "new_server" }
        let(:new_remote_path) { "/another/path" }

        context "and the NFS share is accessible" do
          let(:reachable) { true }

          it "returns true" do
            expect(subject.validate).to eq true
          end
        end

        context "and the NFS share is not accessible" do
          let(:reachable) { false }

          before { allow(Yast::Popup).to receive(:YesNo).and_return accepted }

          context "and the user does not want to continue" do
            let(:accepted) { false }

            it "returns false" do
              expect(subject.validate).to eq false
            end
          end

          context "but the user wants to continue anyway" do
            let(:accepted) { true }

            it "returns true" do
              expect(subject.validate).to eq true
            end
          end
        end
      end
    end
  end
end
