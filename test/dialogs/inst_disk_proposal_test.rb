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
require "y2storage/dialogs/inst_disk_proposal"
Yast.import "Wizard"
Yast.import "UI"

describe Y2Storage::Dialogs::InstDiskProposal do
  subject(:dialog) { Y2Storage::Dialogs::InstDiskProposal.new }

  describe "#run" do
    let(:proposal) { double("Y2Storage::Proposal").as_null_object }

    before do
      allow(Yast::Wizard).to receive(:CreateDialog).and_return(true)
      allow(Yast::UI).to receive(:UserInput).and_return :next
      allow(Yast::Wizard).to receive(:CloseDialog).and_return(true)

      allow(Y2Storage::Proposal).to receive(:new).and_return proposal
    end

    context "when the proposal succeeds" do
      let(:devicegraph) { double("Storage::Devicegraph", actiongraph: actiongraph) }
      let(:actiongraph) { double("Storage::Actiongraph", commit_actions_as_strings: actions) }
      let(:actions) { ["Action 1", "Action 2"] }

      before do
        allow(proposal).to receive(:propose)
        allow(proposal).to receive(:devices).and_return devicegraph
      end

      it "displays the list of actions" do
        expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
          expect(content.to_s).to include "<li>Action 1</li><li>Action 2</li>"
        end
        dialog.run
      end
    end

    context "when the proposal fails" do
      before do
        allow(proposal).to receive(:propose).and_raise Y2Storage::Proposal::Error
      end

      it "displays an error message" do
        expect(Yast::Wizard).to receive(:SetContents) do |_title, content|
          expect(content.to_s).to include "No proposal possible"
        end
        dialog.run
      end
    end
  end
end
