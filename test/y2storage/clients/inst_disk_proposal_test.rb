#!/usr/bin/env rspec
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
    let(:guided_dialog) { double("Y2Storage::Dialogs::GuidedSetup") }
    let(:storage_manager) { Y2Storage::StorageManager.instance }

    before do
      Y2Storage::StorageManager.create_test_instance
      # Ensure probing
      storage_manager.probe
      allow(proposal_dialog).to receive(:proposal)
      allow(proposal_dialog).to receive(:devicegraph)
      allow(Y2Storage::GuidedProposal).to receive(:initial).and_return(initial_proposal)

      allow(Yast::ProductFeatures).to receive(:GetSection).with("partitioning")
        .and_return(partitioning_section)
    end

    let(:initial_proposal) { double("Y2Storage::GuidedProposal", devices: initial_devicegraph) }
    let(:initial_devicegraph) { double("Y2Storage::Devicegraph") }

    let(:partitioning_section) { {} }

    it "it does not exclude the Guided Setup button" do
      allow(proposal_dialog).to receive(:run).and_return(:abort)

      expect(Y2Storage::Dialogs::Proposal).to receive(:new)
        .with(anything, anything, excluded_buttons: []).and_return(proposal_dialog)

      client.run
    end

    context "when running the client for the first time" do
      before do
        allow(storage_manager).to receive(:proposal).and_return nil
        allow(storage_manager).to receive(:staging_changed?).and_return false
      end

      let(:proposal_settings) { double("Y2Storage::ProposalSettings") }

      it "creates initial proposal settings based on the product (control.xml)" do
        expect(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
          .and_return(proposal_settings)
        expect(Y2Storage::GuidedProposal).to receive(:initial)
          .with(hash_including(settings: proposal_settings))

        allow(Y2Storage::Dialogs::Proposal).to receive(:new).and_return proposal_dialog
        allow(proposal_dialog).to receive(:run).and_return :abort
        client.run
      end

      it "opens the proposal dialog with the initial proposal" do
        expect(Y2Storage::Dialogs::Proposal).to receive(:new) do |proposal, devicegraph|
          expect(proposal).to eq initial_proposal
          expect(devicegraph).to eq proposal.devices
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
          .with(previous_proposal, storage_manager.staging, anything).and_return(proposal_dialog)

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
          .with(nil, storage_manager.staging, anything).and_return(proposal_dialog)

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
        allow(storage_manager.staging).to receive(:used_features).and_return 0
      end

      context "if the dialog provides an accepted proposal" do
        before do
          allow(proposal_dialog).to receive(:proposal).and_return new_proposal
          allow(proposal_dialog).to receive(:devicegraph)
          allow(new_devicegraph).to receive(:safe_copy)
        end

        it "stores the proposal in the storage manager" do
          client.run
          expect(storage_manager.proposal).to eq new_proposal
        end

        it "copies the proposal devicegraph to the staging devicegraph" do
          expect(new_devicegraph).to receive(:safe_copy).with(storage_manager.staging)

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
          allow(new_devicegraph).to receive(:safe_copy)
        end

        it "sets the proposal to nil in the storage manager" do
          client.run
          expect(storage_manager.proposal).to eq nil
        end

        it "copies the forced devicegraph to the staging devicegraph" do
          expect(new_devicegraph).to receive(:safe_copy).with(storage_manager.staging)

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

    describe "if the guided setup button is pressed in the proposal dialog" do
      before do
        allow(Y2Storage::Dialogs::Proposal).to receive(:new).and_return(proposal_dialog)
        # First try to open the guided setup, then force quit to end the test
        allow(proposal_dialog).to receive(:run).and_return(:guided, :abort)

        allow(initial_proposal).to receive(:settings).and_return proposal_settings
      end

      let(:proposal_settings) { double("Y2Storage::ProposalSettings") }

      context "when the staging devicegraph has been manually set" do
        before { allow(proposal_dialog).to receive(:proposal).and_return nil }

        it "ask the user for confirmation" do
          expect(Yast::Popup).to receive(:YesNo)
          client.run
        end

        context "and the user confirms to continue" do
          before { allow(Yast::Popup).to receive(:YesNo).and_return true }

          it "opens the guided setup dialog" do
            expect(Y2Storage::Dialogs::GuidedSetup).to receive(:new).and_return(guided_dialog)
            expect(guided_dialog).to receive(:run)

            client.run
          end
        end

        context "and the user denies the confirmation" do
          before { allow(Yast::Popup).to receive(:YesNo).and_return false }

          it "does not open the guided setup dialog" do
            expect(Y2Storage::Dialogs::GuidedSetup).to_not receive(:new)

            client.run
          end
        end
      end

      context "when the staging devicegraph has been set by a proposal" do
        before do
          allow(proposal_dialog).to receive(:proposal).and_return initial_proposal

          allow(Y2Storage::Dialogs::GuidedSetup).to receive(:new).and_return(guided_dialog)
        end

        it "does not ask the user for confirmation" do
          allow(guided_dialog).to receive(:run)

          expect(Yast::Popup).to_not receive(:YesNo)
          client.run
        end

        it "opens the guided setup dialog" do
          expect(Y2Storage::Dialogs::GuidedSetup).to receive(:new)
          expect(guided_dialog).to receive(:run)

          client.run
        end
      end
    end

    describe "calling the expert partitioner" do
      let(:partitioner) { double("Y2Partitioner::Dialogs::Main") }

      before do
        allow(Y2Partitioner::Dialogs::Main).to receive(:new).and_return partitioner
        allow(partitioner).to receive(:run)
        allow(partitioner).to receive(:device_graph)
        allow(Y2Storage::Dialogs::Proposal).to receive(:new).and_return(proposal_dialog)

        # First open the partitioner, then force quit to end the test
        allow(proposal_dialog).to receive(:run).and_return(action, :abort)
      end

      shared_examples "not open partitioner" do
        it "does not open the partitioner" do
          expect(partitioner).to_not receive(:run)

          client.run
        end
      end

      shared_examples "not show warning" do
        it "does not show a warning" do
          expect(Yast2::Popup).to_not receive(:show)

          client.run
        end
      end

      context "if received :expert_from_proposal from the proposal dialog" do
        let(:action) { :expert_from_proposal }

        before do
          allow(proposal_dialog).to receive(:devicegraph).and_return proposed_graph
        end

        context "if there is a proposed devicegraph" do
          let(:proposed_graph) { double("Y2Storage::Devicegraph") }

          shared_examples "open partitioner with devicegraph" do
            it "opens the partitioner with the proposed devicegraph as starting point" do
              expect(Y2Partitioner::Dialogs::Main).to receive(:new)
                .with(storage_manager.probed, proposed_graph).and_return(partitioner)

              expect(partitioner).to receive(:run)

              client.run
            end
          end

          context "and the settings does not contain 'expert_partitioner_warning'" do
            let(:partitioning_section) { {} }

            include_examples "not show warning"

            include_examples "open partitioner with devicegraph"
          end

          context "and the settings are configured to not show the partitioner warning" do
            let(:partitioning_section) { { "expert_partitioner_warning" => false } }

            include_examples "not show warning"

            include_examples "open partitioner with devicegraph"
          end

          context "and the settings are configured to show the partitioner warning" do
            let(:partitioning_section) { { "expert_partitioner_warning" => true } }

            before do
              allow(Yast2::Popup).to receive(:show).and_return(answer)
            end

            let(:answer) { nil }

            it "shows the partitioner warning" do
              expect(Yast2::Popup).to receive(:show)

              client.run
            end

            context "and the user continues" do
              let(:answer) { :continue }

              include_examples "open partitioner with devicegraph"
            end

            context "and the user cancels" do
              let(:answer) { :cancel }

              include_examples "not open partitioner"
            end
          end
        end

        context "if no devicegraph has been proposed" do
          let(:proposed_graph) { nil }

          include_examples "not show warning"

          include_examples "not open partitioner"
        end
      end

      context "if received :expert_from_probed from the proposal dialog" do
        let(:action) { :expert_from_probed }

        shared_examples "open partitioner with probed devicegraph" do
          it "opens the partitioner with the probed devicegraph as starting point" do
            expect(Y2Partitioner::Dialogs::Main).to receive(:new)
              .with(storage_manager.probed, storage_manager.probed).and_return(partitioner)

            expect(partitioner).to receive(:run)

            client.run
          end
        end

        context "and the settings does not contain 'expert_partitioner_warning'" do
          let(:partitioning_section) { {} }

          include_examples "not show warning"

          include_examples "open partitioner with probed devicegraph"
        end

        context "and the settings are configured to not show the partitioner warning" do
          let(:partitioning_section) { { "expert_partitioner_warning" => false } }

          include_examples "not show warning"

          include_examples "open partitioner with probed devicegraph"
        end

        context "and the settings are configured to show the partitioner warning" do
          let(:partitioning_section) { { "expert_partitioner_warning" => true } }

          before do
            allow(Yast2::Popup).to receive(:show).and_return(answer)
          end

          let(:answer) { nil }

          it "shows the partitioner warning" do
            expect(Yast2::Popup).to receive(:show)

            client.run
          end

          context "and the user continues" do
            let(:answer) { :continue }

            include_examples "open partitioner with probed devicegraph"
          end

          context "and the user cancels" do
            let(:answer) { :cancel }

            include_examples "not open partitioner"
          end
        end
      end
    end

    context "processing the guided setup result" do
      let(:devicegraph) { double("Y2Storage::Devicegraph") }
      let(:settings) { double("Storage::ProposalSettings") }
      let(:proposal) { double("Y2Storage::GuidedProposal", devices: devicegraph, settings: settings) }
      let(:second_proposal_dialog) { double("Y2Storage::Dialogs::Proposal").as_null_object }

      before do
        allow(proposal_dialog).to receive(:run).and_return :guided
        allow(Y2Storage::Dialogs::GuidedSetup).to receive(:new).and_return(guided_dialog)
        # Just to quit
        allow(second_proposal_dialog).to receive(:run).and_return :abort

        # Just to make sure the popup about overwriting a manual setup is not raised
        allow(proposal_dialog).to receive(:proposal).and_return(proposal)
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

      context "if the guided setup returns :cancel" do
        before do
          allow(proposal_dialog).to receive(:devicegraph).and_return(devicegraph)
          allow(guided_dialog).to receive(:run).and_return :cancel
        end

        it "opens a new proposal dialog again with the same values" do
          expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
            .and_return(proposal_dialog)
          expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
            .with(proposal, devicegraph, anything).and_return(second_proposal_dialog)
          client.run
        end
      end

      context "if the guided setup returns :back" do
        before do
          allow(proposal_dialog).to receive(:devicegraph).and_return(devicegraph)
          allow(guided_dialog).to receive(:run).and_return :back
        end

        it "opens a new proposal dialog again with the same values" do
          expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
            .and_return(proposal_dialog)
          expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
            .with(proposal, devicegraph, anything).and_return(second_proposal_dialog)
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

    # TODO: Too much mocking in these tests (think about rewrite them).
    context "processing the expert partitioner result" do
      before do
        allow(Y2Storage::Dialogs::Proposal).to receive(:new).and_return(proposal_dialog)
        allow(proposal_dialog).to receive(:run).and_return :expert_from_proposal
        allow(proposal_dialog).to receive(:proposal).and_return(proposal)
        allow(proposal_dialog).to receive(:devicegraph).and_return(devicegraph)

        allow(Y2Partitioner::Dialogs::Main).to receive(:new).and_return(expert_dialog)
        allow(expert_dialog).to receive(:run).and_return(result)
        allow(expert_dialog).to receive(:device_graph).and_return(new_devicegraph)

        # Just to quit
        allow(second_proposal_dialog).to receive(:run).and_return :abort
      end

      let(:devicegraph) { double("Y2Storage::Devicegraph") }
      let(:new_devicegraph) { double("Y2Storage::Devicegraph") }
      let(:proposal) { double("Y2Storage::GuidedProposal") }
      let(:expert_dialog) { double("Y2Partitioner::Dialogs::Main") }
      let(:second_proposal_dialog) { double("Y2Storage::Dialogs::Proposal").as_null_object }

      context "if the expert partitioner returns :abort" do
        let(:result) { :abort }

        it "aborts" do
          expect(client.run).to eq :abort
        end
      end

      context "if the expert partitioner returns :back" do
        let(:result) { :back }

        before do
          allow(storage_manager).to receive(:staging_changed?).and_return(false)
          allow(storage_manager).to receive(:staging_revision).and_return(*staging_revisions)
        end

        context "and the system was not reprobed" do
          let(:staging_revisions) { [1, 1] }

          it "opens a new proposal dialog again with the same values" do
            expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
              .and_return(proposal_dialog)
            expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
              .with(proposal, devicegraph, anything).and_return(second_proposal_dialog)
            client.run
          end
        end

        context "and the system was reprobed" do
          let(:staging_revisions) { [1, 1, 2] }

          before do
            allow(Y2Storage::GuidedProposal).to receive(:initial)
              .and_return(initial_proposal, new_proposal)
          end

          let(:new_proposal) { double("Y2Storage::GuidedProposal", devices: new_devicegraph) }
          let(:new_devicegraph) { double("Y2Storage::Devicegraph") }

          it "opens a new proposal dialog with a new proposal" do
            expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
              .and_return(proposal_dialog)
            expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
              .with(new_proposal, new_devicegraph, anything).and_return(second_proposal_dialog)
            client.run
          end
        end
      end

      context "if the expert partitioner returns :next" do
        let(:result) { :next }

        it "opens a new proposal dialog with a new devicegraph and without any proposal" do
          expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
            .and_return(proposal_dialog)
          expect(Y2Storage::Dialogs::Proposal).to receive(:new).once.ordered
            .with(nil, new_devicegraph, anything)
            .and_return(second_proposal_dialog)
          client.run
        end
      end
    end
  end
end
