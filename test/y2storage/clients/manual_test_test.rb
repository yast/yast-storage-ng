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
# find current contact information at www.suse.com.

require_relative "../spec_helper"
require "y2storage/clients/manual_test"

describe Y2Storage::Clients::ManualTest do
  describe ".run" do
    before do
      allow(Yast::WFM).to receive(:Args).and_return(args)
      allow(Y2Partitioner::Clients::Main).to receive(:new).and_return partitioner_client
      allow(Y2Storage::Clients::InstDiskProposal).to receive(:new).and_return proposal_client
      allow(Y2Storage::StorageManager).to receive(:create_test_instance)
      allow(Y2Storage::StorageManager).to receive(:instance).and_return storage_manager
    end

    let(:storage_manager) { double("StorageManager", probe_from_file: nil) }
    let(:partitioner_client) { double("Main", run: :next) }
    let(:proposal_client) { double("InstDiskProposal", run: :next) }

    RSpec.shared_examples "abort" do
      it "shows the help text" do
        expect { described_class.run }.to output(/yast2 storage_testing/).to_stderr
      end

      it "returns :abort" do
        allow(Warning).to receive(:warn)
        expect(described_class.run).to eq :abort
      end
    end

    RSpec.shared_examples "mock devicegraph" do
      it "mocks the devicegraph with the given file" do
        expect(storage_manager).to receive(:probe_from_file).with(args[1])
        described_class.run
      end
    end

    context "if no arguments are provided" do
      let(:args) { [] }

      it "reports the corresponding error" do
        expect { described_class.run }.to output(/No action/).to_stderr
      end

      include_examples "abort"
    end

    context "if a wrong action is specified" do
      let(:args) { ["whatever"] }

      it "reports the corresponding error" do
        expect { described_class.run }.to output(/Unknown action/).to_stderr
      end

      include_examples "abort"
    end

    context "partitioner action without a devicegraph" do
      let(:args) { ["partitioner"] }

      it "reports the corresponding error" do
        expect { described_class.run }.to output(/No devicegraph/).to_stderr
      end

      include_examples "abort"
    end

    context "partitioner action with a devicegraph file not ending in xml/yml/yaml" do
      let(:args) { ["partitioner", "devicegraph.txt"] }

      it "reports the corresponding error" do
        expect { described_class.run }.to output(/Wrong devicegraph path/).to_stderr
      end

      include_examples "abort"
    end

    context "partitioner action with a devicegraph file ending in .xml" do
      let(:args) { ["partitioner", "devicegraph.xml"] }

      it "mocks the devicegraph with the xml file" do
        expect(storage_manager).to receive(:probe_from_file).with("devicegraph.xml")
        described_class.run
      end

      it "opens the partitioner" do
        expect(partitioner_client).to receive(:run)
        described_class.run
      end
    end

    context "partitioner action with a devicegraph file ending in .yaml" do
      let(:args) { ["partitioner", "/path/to/devicegraph.yaml"] }

      it "mocks the devicegraph with the YAML file" do
        expect(storage_manager).to receive(:probe_from_file).with("/path/to/devicegraph.yaml")
        described_class.run
      end

      it "opens the partitioner" do
        expect(partitioner_client).to receive(:run)
        described_class.run
      end
    end

    context "proposal action without a devicegraph" do
      let(:args) { ["partitioner"] }

      it "reports the corresponding error" do
        expect { described_class.run }.to output(/No devicegraph/).to_stderr
      end

      include_examples "abort"
    end

    context "proposal action with a devicegraph file and no control file" do
      let(:args) { ["proposal", "devicegraph.xml"] }

      include_examples "mock devicegraph"

      it "uses the product features from the current system" do
        expect(Yast::ProductFeatures).to_not receive(:Import)
        described_class.run
      end

      it "opens the proposal client" do
        expect(proposal_client).to receive(:run)
        described_class.run
      end
    end

    context "proposal action with a devicegraph file and a control file" do
      let(:args) { ["proposal", "/path/to/devicegraph.xml", "control.xml"] }

      before do
        allow(Yast::XML).to receive(:XMLToYCPFile).and_return(some: "value")
      end

      include_examples "mock devicegraph"

      it "mocks the product features" do
        profile = { some: "value" }
        expect(Yast::ProductFeatures).to receive(:Import).with(profile)
        described_class.run
      end

      it "opens the proposal client" do
        expect(proposal_client).to receive(:run)
        described_class.run
      end
    end

    context "autoinst action without a devicegraph" do
      let(:args) { ["autoinst"] }

      it "reports the corresponding error" do
        expect { described_class.run }.to output(/No devicegraph/).to_stderr
      end

      include_examples "abort"
    end

    context "autoinst action with a devicegraph file and no profile" do
      let(:args) { ["autoinst", "/path/to/devicegraph.xml"] }

      it "reports the corresponding error" do
        expect { described_class.run }.to output(/No AutoYaST profile/).to_stderr
      end

      include_examples "abort"
    end

    context "autoinst action with a devicegraph file and a profile" do
      let(:args) { ["autoinst", "/path/to/devicegraph.xml", "/the/profile.xml"] }

      before do
        allow(Yast::Profile).to receive(:ReadXML)
        allow(Yast::Profile).to receive(:current).and_return({})
        allow(Yast::AutoinstConfig).to receive(:Confirm=)
        allow(Yast::AutoinstStorage).to receive(:Import)
        allow(Installation::ProposalRunner).to receive(:new).and_return runner

        Yast.import "Wizard"
        allow(Yast::Wizard).to receive(:OpenNextBackDialog)
        allow(Yast::Wizard).to receive(:CloseDialog)
      end

      let(:runner) { double("ProposalRunner", run: :next) }

      include_examples "mock devicegraph"

      it "loads and imports the profile" do
        expect(Yast::Profile).to receive(:ReadXML).with("/the/profile.xml")
        expect(Yast::AutoinstStorage).to receive(:Import)
        described_class.run
      end

      it "displays the proposal dialog" do
        expect(Yast::AutoinstConfig).to receive(:Confirm=).with(true)
        expect(runner).to receive(:run)
        described_class.run
      end
    end
  end
end
