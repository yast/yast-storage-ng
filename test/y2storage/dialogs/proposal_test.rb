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
require "y2storage/dialogs/proposal"
Yast.import "Wizard"
Yast.import "UI"
Yast.import "Popup"
Yast.import "Report"

describe Y2Storage::Dialogs::Proposal do
  include Yast::UIShortcuts

  subject(:dialog) do
    Y2Storage::Dialogs::Proposal.new(proposal, devicegraph0,
      excluded_buttons: excluded_buttons)
  end

  let(:excluded_buttons) { [] }

  describe "#run" do
    let(:devicegraph0) { double("Storage::Devicegraph", actiongraph: actiongraph0) }
    let(:actiongraph0) { double("Storage::Actiongraph") }
    let(:actions_presenter0) do
      double(Y2Storage::ActionsPresenter, to_html: presenter_content0)
    end
    let(:presenter_content0) { "<li>Action 1</li><li>Action 2</li>" }

    let(:devicegraph1) { double("Storage::Devicegraph", actiongraph: actiongraph1) }
    let(:actiongraph1) { double("Storage::Actiongraph") }
    let(:actions_presenter1) do
      double(Y2Storage::ActionsPresenter, to_html: presenter_content1)
    end
    let(:presenter_content1) { "<li>Action 3</li><li>Action 4</li>" }

    let(:actions_presenter2) { double(Y2Storage::ActionsPresenter, to_html: nil) }

    before do
      Y2Storage::StorageManager.create_test_instance

      # Mock opening and closing the dialog
      allow(Yast::Wizard).to receive(:CreateDialog).and_return true
      allow(Yast::Wizard).to receive(:CloseDialog).and_return true
      # Always confirm when clicking in abort
      allow(Yast::Popup).to receive(:ConfirmAbort).and_return true
      # Most straightforward scenario. Just click next
      allow(Yast::UI).to receive(:UserInput).once.and_return :next

      allow(Y2Storage::ActionsPresenter)
        .to receive(:new).with(actiongraph0).and_return actions_presenter0
      allow(Y2Storage::ActionsPresenter)
        .to receive(:new).with(actiongraph1).and_return actions_presenter1
      allow(Y2Storage::ActionsPresenter)
        .to receive(:new).with(nil).and_return actions_presenter2
    end

    # Convenience method to inspect the tree of terms for the UI
    def nested_id_term(id, term)
      term.nested_find do |i|
        i.is_a?(Yast::Term) && i.value == :id && i.params.first == id
      end
    end

    # Convenience method to inspect the tree of terms for the UI
    def menu_button_item_with_id(id, content)
      content.nested_find do |i|
        next unless i.is_a?(Yast::Term)
        next unless i.value == :MenuButton

        items = i.params.last
        items.any? { |item| nested_id_term(id, item) }
      end
    end

    let(:proposal) do
      double("Y2Storage::GuidedProposal", proposed?: proposed, auto_settings_adjustment: adjustment)
    end
    let(:adjustment) { nil }

    let(:proposed) { true }

    shared_examples "partitioner from proposal" do
      context "and the button for partitioner from proposal is not excluded" do
        let(:excluded_buttons) { [] }

        it "displays an option to run the partitioner from the current devicegraph" do
          expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
            expect(menu_button_item_with_id(:expert_from_proposal, content)).to_not be_nil
          end
          dialog.run
        end
      end

      context "and the button for partitioner from proposal is excluded" do
        let(:excluded_buttons) { [:expert_from_proposal] }

        it "does not display an option to run the partitioner from the current devicegraph" do
          expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
            expect(menu_button_item_with_id(:expert_from_proposal, content)).to be_nil
          end
          dialog.run
        end
      end
    end

    context "when Guided Setup button is not excluded" do
      let(:excluded_buttons) { [] }

      it "displays the button to run the Guided Setup" do
        expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
          expect(nested_id_term(:guided, content)).to_not be_nil
        end
        dialog.run
      end
    end

    context "when Guided Setup button is excluded" do
      let(:excluded_buttons) { [:guided] }

      it "does not display the button to run the Guided Setup" do
        expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
          expect(nested_id_term(:guided, content)).to be_nil
        end
        dialog.run
      end
    end

    context "when the button for partitioner from probed is not excluded" do
      let(:excluded_buttons) { [] }

      it "displays an option to run the partitioner from the probed devicegraph" do
        expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
          expect(menu_button_item_with_id(:expert_from_probed, content)).to_not be_nil
        end
        dialog.run
      end
    end

    context "when the button for partitioner from probed is excluded" do
      let(:excluded_buttons) { [:expert_from_probed] }

      it "does not display an option to run the partitioner from the probed devicegraph" do
        expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
          expect(menu_button_item_with_id(:expert_from_probed, content)).to be_nil
        end
        dialog.run
      end
    end

    context "when a pristine proposal is provided" do
      let(:proposed) { false }

      it "calculates the proposed devicegraph" do
        allow(proposal).to receive(:devices).and_return devicegraph1

        expect(proposal).to receive(:propose)
        dialog.run
      end

      context "if the proposal succeeds" do
        before do
          allow(proposal).to receive(:propose)
          allow(proposal).to receive(:devices).and_return devicegraph1
        end

        it "displays the content of the summary widget for the calculated devicegraph" do
          expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
            expect(content.to_s).to include presenter_content1
          end
          dialog.run
        end

        it "displays an explanation about user-driven Guided Setup" do
          expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
            expect(content.to_s).to include "Guided Setup with the settings provided by the user"
          end
          dialog.run
        end

        it "sets #proposal to the provided proposal" do
          dialog.run
          expect(dialog.proposal).to eq proposal
        end

        it "sets #devicegraph to the calculated devicegraph" do
          dialog.run
          expect(dialog.devicegraph).to eq devicegraph1
        end

        include_examples "partitioner from proposal"
      end

      context "if the proposal fails" do
        before do
          allow(proposal).to receive(:propose).and_raise Y2Storage::Error

          # In this case, we just want to inspect the dialog content and then quit
          allow(Yast::UI).to receive(:UserInput).once.and_return :abort
        end

        it "displays an error message about failed Guided Setup" do
          # We don't break the event loop, so there is a second call to UserInput
          expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
            expect(content.to_s).to include "Guided Setup was not able to propose"
          end
          dialog.run
        end

        it "does not let the user continue" do
          expect(Yast::Report).to receive(:Error)
          # We don't break the event loop, so there is a second call to UserInput
          expect(Yast::UI).to receive(:UserInput).twice.and_return(:next, :abort)
          dialog.run
        end

        it "sets #devicegraph to nil" do
          dialog.run
          expect(dialog.devicegraph).to be_nil
        end

        it "does not display an option to run the partitioner from the current devicegraph" do
          expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
            expect(menu_button_item_with_id(:expert_from_proposal, content)).to be_nil
          end
          dialog.run
        end
      end
    end

    context "when an already calculated proposal is provided" do
      let(:proposed) { true }

      it "does not re-calculate the proposed devicegraph" do
        expect(proposal).to_not receive(:propose)
        dialog.run
      end

      it "displays the content of the summary widget for the provided devicegraph" do
        expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
          expect(content.to_s).to include presenter_content0
        end
        dialog.run
      end

      context "if it's an initial proposal with the default settings" do
        let(:adjustment) { Y2Storage::Proposal::SettingsAdjustment.new }

        context "and there is a resulting devicegraph" do
          it "displays an explanation about initial proposal with default settings" do
            expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
              expect(content.to_s).to include "proposed with the default Guided Setup settings"
            end
            dialog.run
          end
        end

        context "and there is no resulting devicegraph" do
          let(:devicegraph0) { nil }

          it "displays an error about using default settings" do
            # In this case, we just want to inspect the dialog content and then quit
            allow(Yast::UI).to receive(:UserInput).once.and_return :abort

            expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
              expect(content.to_s).to include(
                "not possible to propose", "default Guided Setup settings"
              )
            end
            dialog.run
          end
        end
      end

      context "if it's an initial proposal with some adjusted settings" do
        let(:adjustment) do
          vol = double("Y2Storage::VolumeSpecification", mount_point: "/")
          adj = Y2Storage::Proposal::SettingsAdjustment.new
          adj.add_volume_attr(vol, :adjust_by_ram, false)
        end

        context "and there is a resulting devicegraph" do
          it "displays an explanation about success with adjusted settings" do
            expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
              expect(content.to_s).to include(
                "proposed after adjusting the Guided Setup settings",
                "do not adjust size of /"
              )
            end
            dialog.run
          end
        end

        context "and there is no resulting devicegraph" do
          let(:devicegraph0) { nil }

          it "displays an error about failure with adjusted settings" do
            # In this case, we just want to inspect the dialog content and then quit
            allow(Yast::UI).to receive(:UserInput).once.and_return :abort

            expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
              expect(content.to_s).to include(
                "not possible to propose",
                "after adjusting the Guided Setup settings",
                "do not adjust size of /"
              )
            end
            dialog.run
          end
        end
      end

      context "if it's a proposal created via Guided Setup" do
        let(:adjustment) { nil }

        context "and there is a resulting devicegraph" do
          it "displays an message about successful user-driven Guided Setup" do
            expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
              expect(content.to_s).to include(
                "proposed by the Guided Setup",
                "settings provided by the user"
              )
            end
            dialog.run
          end
        end

        context "and there is no resulting devicegraph" do
          let(:devicegraph0) { nil }

          it "displays an error about failure with user-provided settings" do
            # In this case, we just want to inspect the dialog content and then quit
            allow(Yast::UI).to receive(:UserInput).once.and_return :abort

            expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
              expect(content.to_s).to include(
                "not able to propose",
                "using the provided settings"
              )
            end
            dialog.run
          end
        end
      end

      it "sets #proposal to the provided proposal" do
        dialog.run
        expect(dialog.proposal).to eq proposal
      end

      it "sets #devicegraph to the provided devicegraph" do
        dialog.run
        expect(dialog.devicegraph).to eq devicegraph0
      end

      include_examples "partitioner from proposal"
    end

    context "when no proposal is provided" do
      let(:proposal) { nil }

      it "displays the content of the summary widget for the provided devicegraph" do
        expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
          expect(content.to_s).to include presenter_content0
        end
        dialog.run
      end

      it "sets #proposal to nil" do
        dialog.run
        expect(dialog.proposal).to be_nil
      end

      it "sets #devicegraph to the provided devicegraph" do
        dialog.run
        expect(dialog.devicegraph).to eq devicegraph0
      end

      include_examples "partitioner from proposal"
    end

    context "when an actions presenter event happens" do
      let(:proposal) { nil }
      let(:event) { "event" }

      before do
        allow(Yast::UI).to receive(:UserInput).twice.and_return(event, :next)
        allow(actions_presenter0).to receive(:can_handle?).with(event).and_return(true)
        allow(actions_presenter0).to receive(:update_status)
      end

      it "updates the actions presenter" do
        expect(actions_presenter0).to receive(:update_status).with(event)
        dialog.run
      end

      it "refresh the summary" do
        expect(Yast::UI).to receive(:ChangeWidget).with(Id(:summary), :Value, anything)
        dialog.run
      end
    end

    context "when the user decides to run the expert partitioner from the proposed devicegraph" do
      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:expert_from_proposal)
      end

      it "returns :expert_from_proposal" do
        expect(dialog.run).to eq :expert_from_proposal
      end
    end

    context "when the user decides to run the expert partitioner from the probed devicegraph" do
      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:expert_from_probed)
      end

      it "returns :expert_from_probed" do
        expect(dialog.run).to eq :expert_from_probed
      end
    end
  end
end
