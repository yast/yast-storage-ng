#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2017] SUSE LLC
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

require_relative "../../spec_helper"
require "storage"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::Proposal::InitialStrategies::Legacy do
  using Y2Storage::Refinements::SizeCasts

  include_context "proposal"

  let(:scenario) { "empty_hard_disk_gpt_25GiB" }

  let(:settings_format) { :legacy }

  describe "#initial_proposal" do
    subject(:proposal) { described_class.new.initial_proposal(settings: current_settings) }

    before do
      settings.root_filesystem_type = root_filesystem
      settings.use_snapshots = snapshots
      settings.root_base_size = root_base_size
      settings.root_max_size = root_max_size
      settings.home_min_size = home_min_size
    end

    let(:root_filesystem) { Y2Storage::Filesystems::Type::BTRFS }
    let(:snapshots) { settings.use_snapshots }
    let(:root_base_size) { settings.root_base_size }
    let(:root_max_size) { settings.root_max_size }
    let(:home_min_size) { settings.home_min_size }

    let(:current_settings) { settings }

    context "when settings are not passed" do
      let(:current_settings) { nil }

      it "creates initial proposal settings based on the product (control.xml)" do
        expect(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
          .and_call_original
        proposal
      end
    end

    context "when it is possible to create a proposal using current settings" do
      let(:separate_home) { true }
      let(:snapshots) { true }
      let(:root_base_size) { 3.GiB }
      let(:root_max_size) { 3.GiB }
      let(:home_min_size) { 5.GiB }

      it "makes a valid proposal without changing settings" do
        expect(proposal.settings.use_separate_home).to be true
        expect(proposal.settings.use_snapshots).to be true
        expect(proposal.devices).to_not be_nil
      end
    end

    context "when it is not possible to create a proposal using separate home" do
      let(:separate_home) { true }
      let(:snapshots) { true }
      let(:root_base_size) { 5.GiB }
      let(:root_max_size) { 5.GiB }
      let(:home_min_size) { 5.GiB }

      it "tries without separate home" do
        expect(proposal.settings.use_separate_home).to be false
      end

      context "and it is possible without separate home" do
        it "makes a valid proposal only deactivating separate home" do
          expect(proposal.settings.use_snapshots).to be true
          expect(proposal.devices).to_not be_nil
        end
      end

      context "and it is not possible without separate home" do
        let(:root_base_size) { 10.GiB }
        let(:root_max_size) { 10.GiB }

        it "tries without snapshots" do
          expect(proposal.settings.use_snapshots).to be false
        end

        context "and it is possible without snapshots" do
          it "makes a valid proposal deactivating snapshots" do
            expect(proposal.settings.use_snapshots).to be false
            expect(proposal.devices).to_not be_nil
          end
        end

        context "and it is not possible without snapshots" do
          let(:root_base_size) { 25.GiB }
          let(:root_max_size) { 25.GiB }

          it "does not make a valid proposal" do
            expect(proposal.settings.use_separate_home).to be false
            expect(proposal.settings.use_snapshots).to be false
            expect(proposal.devices).to be_nil
          end
        end
      end
    end
  end
end
