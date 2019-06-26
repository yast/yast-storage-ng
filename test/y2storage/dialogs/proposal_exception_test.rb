#!/usr/bin/env rspec
# Copyright (c) [2019] SUSE LLC
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

describe Y2Storage::Dialogs::Proposal do
  include Yast::UIShortcuts

  subject(:dialog) do
    Y2Storage::Dialogs::Proposal.new(nil, fake_devicegraph)
  end

  describe "when the devicegraph is wrong (i.e. Devicegraph#actiongraph raises an exception)" do
    before { fake_scenario("wrong_luks.xml") }

    describe "#run" do
      let(:actions_presenter) do
        double(Y2Storage::ActionsPresenter, to_html: "")
      end

      before do
        # Mock opening and closing the dialog
        allow(Yast::Wizard).to receive(:CreateDialog).and_return true
        allow(Yast::Wizard).to receive(:CloseDialog).and_return true
        # Most straightforward scenario. Just click next
        allow(Yast::UI).to receive(:UserInput).once.and_return :next

        allow(Yast2::Popup).to receive(:show)
        allow(Y2Storage::ActionsPresenter).to receive(:new).and_return actions_presenter
      end

      it "does not crash" do
        expect { dialog.run }.to_not raise_error
      end

      it "displays an informative pop-up about the libstorage-ng exception" do
        expect(Yast2::Popup).to receive(:show).with(/installation may fail/, details: /Luks bigger/)
        dialog.run
      end

      it "initializes the actions presenter with nil" do
        expect(Y2Storage::ActionsPresenter).to receive(:new).with(nil)
        dialog.run
      end
    end
  end
end
