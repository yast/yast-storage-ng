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
require "y2storage/dialogs/guided_setup/widgets/linux_partition_actions"

describe Y2Storage::Dialogs::GuidedSetup::Widgets::LinuxPartitionActions do
  include_context "widgets"

  subject { described_class.new(:linux_actions, settings, enabled: enabled) }

  let(:settings) { Y2Storage::ProposalSettings.new }

  let(:enabled) { nil }

  describe "#init" do
    before do
      settings.linux_delete_mode = :ondemand
    end

    it "selects the default option according to the settings" do
      expect_select(:linux_actions, :ondemand)

      subject.init
    end

    context "when the :enabled option is set to true" do
      let(:enabled) { true }

      it "enables the widget" do
        expect_enable(:linux_actions)

        subject.init
      end
    end

    context "when the :enabled option is set to false" do
      let(:enabled) { false }

      it "disables the widget" do
        expect_disable(:linux_actions)

        subject.init
      end
    end
  end

  describe "#store" do
    before do
      select_widget(:linux_actions, :ondemand)
    end

    it "sets settings.linux_delete_mode according to the selected value" do
      expect(settings.linux_delete_mode).to_not eq(:ondemand)

      subject.store

      expect(settings.linux_delete_mode).to eq(:ondemand)
    end
  end
end
