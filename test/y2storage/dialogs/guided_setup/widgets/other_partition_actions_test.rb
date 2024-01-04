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

require_relative "../../../spec_helper"
require_relative "#{TEST_PATH}/support/widgets_context"
require "y2storage/dialogs/guided_setup/widgets/other_partition_actions"

describe Y2Storage::Dialogs::GuidedSetup::Widgets::OtherPartitionActions do
  include_context "widgets"

  subject { described_class.new(:other_actions, settings, enabled:) }

  let(:settings) { Y2Storage::ProposalSettings.new }

  let(:enabled) { nil }

  describe "#init" do
    before do
      settings.other_delete_mode = :ondemand
    end

    it "selects the default option according to the settings" do
      expect_select(:other_actions, value: :ondemand)

      subject.init
    end

    context "when the :enabled option is set to true" do
      let(:enabled) { true }

      it "enables the widget" do
        expect_enable(:other_actions)

        subject.init
      end
    end

    context "when the :enabled option is set to false" do
      let(:enabled) { false }

      it "disables the widget" do
        expect_disable(:other_actions)

        subject.init
      end
    end
  end

  describe "#store" do
    before do
      select_widget(:other_actions, value: :ondemand)
    end

    it "sets settings.other_delete_mode according to the selected value" do
      expect(settings.other_delete_mode).to_not eq(:ondemand)

      subject.store

      expect(settings.other_delete_mode).to eq(:ondemand)
    end
  end
end
