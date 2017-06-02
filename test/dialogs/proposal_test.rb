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
require "y2storage/dialogs/proposal"
Yast.import "Wizard"
Yast.import "UI"
Yast.import "Popup"
Yast.import "Report"

describe Y2Storage::Dialogs::Proposal do
  include Yast::UIShortcuts

  subject(:dialog) { Y2Storage::Dialogs::Proposal.new(proposal, devicegraph0) }

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

    context "when a pristine proposal is provided" do
      let(:proposal) { double("Y2Storage::Proposal", proposed?: false) }

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

        it "sets #proposal to the provided proposal" do
          dialog.run
          expect(dialog.proposal).to eq proposal
        end

        it "sets #devicegraph to the calculated devicegraph" do
          dialog.run
          expect(dialog.devicegraph).to eq devicegraph1
        end
      end

      context "if the proposal fails" do
        before do
          allow(proposal).to receive(:propose).and_raise Y2Storage::Error

          # In this case, we just want to inspect the dialog content and then quit
          allow(Yast::UI).to receive(:UserInput).once.and_return :abort
        end

        it "displays an error message" do
          # We don't break the event loop, so there is a second call to UserInput
          expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
            expect(content.to_s).to include "No proposal possible"
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
      end
    end

    context "when an already calculated proposal is provided" do
      let(:proposal) { double("Y2Storage::Proposal", proposed?: true) }

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

      it "sets #proposal to the provided proposal" do
        dialog.run
        expect(dialog.proposal).to eq proposal
      end

      it "sets #devicegraph to the provided devicegraph" do
        dialog.run
        expect(dialog.devicegraph).to eq devicegraph0
      end
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
  end
end
