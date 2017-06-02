#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2016] SUSE LLC
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
require "y2storage/clients/inst_disk_proposal"

describe Y2Storage::Clients::InstDiskProposal do
  subject(:client) { described_class.new }

  describe "#run" do
    let(:proposal_dialog) { double("Y2Storage::Dialogs::Proposal") }
    let(:storage_manager) { Y2Storage::StorageManager.instance }

    before do
      Y2Storage::StorageManager.create_test_instance
      allow(proposal_dialog).to receive(:proposal)
      allow(proposal_dialog).to receive(:devicegraph)
    end

    context "when running the client for the first time " do
      before do
        allow(storage_manager).to receive(:proposal).and_return nil
        allow(storage_manager).to receive(:staging_changed?).and_return false
      end

      let(:proposal_settings) { double("Y2Storage::ProposalSettings") }

      it "creates initial proposal settings based on the product (control.xml)" do
        expect(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
          .and_return(proposal_settings)
        expect(Y2Storage::GuidedProposal).to receive(:new)
          .with(hash_including(settings: proposal_settings))

        allow(Y2Storage::Dialogs::Proposal).to receive(:new).and_return proposal_dialog
        allow(proposal_dialog).to receive(:run).and_return :abort
        client.run
      end

      it "opens the proposal dialog with a pristine proposal" do
        expect(Y2Storage::Dialogs::Proposal).to receive(:new) do |proposal, devicegraph|
          expect(proposal).to be_a Y2Storage::GuidedProposal
          expect(proposal.proposed?).to eq false
          expect(devicegraph).to eq storage_manager.y2storage_staging
        end.and_return(proposal_dialog)

        expect(proposal_dialog).to receive(:run).and_return :abort
        client.run
      end
    end

    context "when a proposal has already been accepted" do
      let(:previous_proposal) { double("Y2Storage::GuidedProposal", proposed?: true) }

      before do
        allow(storage_manager).to receive(:proposal).and_return previous_proposal
        allow(storage_manager).to receive(:staging_changed?).and_return true
      end

      it "opens the proposal dialog with the accepted proposal" do
        expect(Y2Storage::Dialogs::Proposal).to receive(:new)
          .with(previous_proposal, storage_manager.y2storage_staging).and_return(proposal_dialog)

        expect(proposal_dialog).to receive(:run).and_return :abort
        client.run
      end
    end

    context "when the staging devicegraph has been manually set" do
      before do
        allow(storage_manager).to receive(:proposal).and_return nil
        allow(storage_manager).to receive(:staging_changed?).and_return true
      end

      it "opens the proposal dialog with no proposal" do
        expect(Y2Storage::Dialogs::Proposal).to receive(:new)
          .with(nil, storage_manager.y2storage_staging).and_return(proposal_dialog)

        expect(proposal_dialog).to receive(:run).and_return :abort
        client.run
      end
    end

    context "after receiving :next from the proposal dialog" do
      let(:new_devicegraph) { double("Y2Storage::Devicegraph", used_features: 0) }
      let(:new_proposal) { double("Y2Storage::GuidedProposal", devices: new_devicegraph) }

      before do
        allow(Y2Storage::Dialogs::Proposal).to receive(:new).and_return(proposal_dialog)
        allow(proposal_dialog).to receive(:run).and_return :next
        allow(storage_manager.y2storage_staging).to receive(:used_features).and_return 0
      end

      context "if the dialog provides an accepted proposal" do
        before do
          allow(proposal_dialog).to receive(:proposal).and_return new_proposal
          allow(proposal_dialog).to receive(:devicegraph)
          allow(new_devicegraph).to receive(:copy)
        end

        it "stores the proposal in the storage manager" do
          client.run
          expect(storage_manager.proposal).to eq new_proposal
        end

        it "copies the proposal devicegraph to the staging devicegraph" do
          expect(new_devicegraph).to receive(:copy).with(storage_manager.y2storage_staging)

          client.run
        end

        it "increments the staging revision" do
          pre_revision = storage_manager.staging_revision

          client.run
          expect(storage_manager.staging_revision).to be > pre_revision
        end

        it "goes to next step" do
          expect(client.run).to eq :next
        end
      end

      context "if the dialog does not provide a proposal" do
        before do
          allow(proposal_dialog).to receive(:proposal).and_return nil
          allow(proposal_dialog).to receive(:devicegraph).and_return new_devicegraph
          allow(new_devicegraph).to receive(:copy)
        end

        it "sets the proposal to nil in the storage manager" do
          client.run
          expect(storage_manager.proposal).to eq nil
        end

        it "copies the forced devicegraph to the staging devicegraph" do
          expect(new_devicegraph).to receive(:copy).with(storage_manager.y2storage_staging)

          client.run
        end

        it "increments the staging revision" do
          pre_revision = storage_manager.staging_revision

          client.run
          expect(storage_manager.staging_revision).to be > pre_revision
        end

        it "goes to next step" do
          expect(client.run).to eq :next
        end
      end
    end

    context "after receiving :abort from the proposal dialog" do
      before do
        allow(Y2Storage::Dialogs::Proposal).to receive(:new).and_return(proposal_dialog)
        allow(proposal_dialog).to receive(:run).and_return :abort
      end

      it "aborts" do
        expect(client.run).to eq :abort
      end
    end

    context "after receiving :back from the proposal dialog" do
      let(:new_devicegraph) { double("Y2Storage::Devicegraph") }
      let(:new_proposal) { double("Y2Storage::GuidedProposal", devices: new_devicegraph) }

      before do
        allow(Y2Storage::Dialogs::Proposal).to receive(:new).and_return(proposal_dialog)
        allow(proposal_dialog).to receive(:devicegraph).and_return new_devicegraph
        allow(proposal_dialog).to receive(:proposal).and_return new_proposal
        allow(proposal_dialog).to receive(:run).and_return :back
      end

      it "does not modify the staging devicegraph" do
        pre_revision = storage_manager.staging_revision
        expect(new_devicegraph).to_not receive(:copy)

        client.run
        expect(storage_manager.staging_revision).to eq pre_revision
      end

      it "does not store the proposal in the storage manager" do
        pre_proposal = storage_manager.proposal
        expect(storage_manager).to_not receive(:proposal=)

        client.run
        expect(storage_manager.proposal).to eq pre_proposal
      end

      it "goes back" do
        expect(client.run).to eq :back
      end
    end

    context "processing the guided setup result" do
      let(:guided_dialog) { double("Y2Storage::Dialogs::GuidedSetup") }
      let(:devicegraph) { double("Y2Storage::Devicegraph") }
      let(:settings) { double("Storage::ProposalSettings") }
      let(:proposal) { double("Y2Storage::GuidedProposal", devices: devicegraph, settings: settings) }
      let(:second_proposal_dialog) { double("Y2Storage::Dialogs::Proposal").as_null_object }

      before do
        allow(proposal_dialog).to receive(:run).and_return :guided
        allow(Y2Storage::Dialogs::GuidedSetup).to receive(:new).and_return(guided_dialog)
        # Just to quit
        allow(second_proposal_dialog).to receive(:run).and_return :abort
      end

      context "if the guided setup returns :abort" do
        before do
          allow(Y2Storage::Dialogs::Proposal).to receive(:new).and_return(proposal_dialog)
          allow(guided_dialog).to receive(:run).and_return :abort
        end

        it "aborts" do
          expect(client.run).to eq :abort
        end
      end

      context "if the guided setup returns :back" do
        before do
          allow(proposal_dialog).to receive(:proposal).and_return(proposal)
          allow(proposal_dialog).to receive(:devicegraph).and_return(devicegraph)
          allow(guided_dialog).to receive(:run).and_return :back
        end

        it "opens a new proposal dialog again with the same values" do
          expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
            .and_return(proposal_dialog)
          expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
            .with(proposal, devicegraph).and_return(second_proposal_dialog)
          client.run
        end
      end

      context "if the guided setup returns :next" do
        let(:new_settings) { double("Y2Storage::ProposalSettings") }

        before do
          allow(proposal_dialog).to receive(:devicegraph).and_return(devicegraph)
          allow(guided_dialog).to receive(:run).and_return :next
          allow(guided_dialog).to receive(:settings).and_return new_settings
        end

        it "opens a new proposal dialog now with the new settings" do
          expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
            .and_return(proposal_dialog)
          expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered do |proposal, graph|
            expect(proposal).to be_a Y2Storage::GuidedProposal
            expect(proposal.proposed?).to eq false
            expect(proposal.settings).to eq new_settings
            expect(graph).to eq devicegraph
          end.and_return(second_proposal_dialog)

          client.run
        end
      end
    end
  end
end
