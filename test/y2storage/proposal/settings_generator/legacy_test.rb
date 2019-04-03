#!/usr/bin/env rspec
# encoding: utf-8

# Copyright (c) [2018] SUSE LLC
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
require "y2storage/proposal/settings_generator/legacy"

describe Y2Storage::Proposal::SettingsGenerator::Legacy do
  subject { described_class.new(settings) }

  describe "#next_settings" do
    before do
      stub_product_features("partitioning" => partitioning_features)
    end

    let(:partitioning_features) do
      {
        "try_separate_home"  => try_separate_home,
        "proposal_snapshots" => proposal_snapshots
      }
    end

    let(:try_separate_home) { true }
    let(:proposal_snapshots) { true }

    let(:settings) { Y2Storage::ProposalSettings.new_for_current_product }

    it "returns a copy of the given settings" do
      next_settings = subject.next_settings

      expect(next_settings).to be_a(Y2Storage::ProposalSettings)
      expect(next_settings.object_id).to_not eq(settings.object_id)
    end

    context "when called for first time" do
      it "returns the same values as the initial settings" do
        expect(subject.next_settings).to eq(settings)
      end
    end

    context "for the next times" do
      before do
        subject.next_settings
      end

      context "when try_separate_home option is active" do
        let(:try_separate_home) { true }

        it "disables the separate home" do
          next_settings = subject.next_settings

          expect(next_settings.use_separate_home).to eq(false)
        end

        it "does not disable the snapshots" do
          next_settings = subject.next_settings

          expect(next_settings.snapshots_active?).to eq(true)
        end
      end

      context "when the try_separate_home option is not active" do
        let(:try_separate_home) { false }

        it "disables the snapshots" do
          next_settings = subject.next_settings

          expect(next_settings.snapshots_active?).to eq(false)
        end
      end

      context "when neither try_separate_home nor proposal_snaphots options are active" do
        let(:try_separate_home) { false }
        let(:proposal_snapshots) { false }

        it "returns nil" do
          expect(subject.next_settings).to be_nil
        end
      end
    end
  end
end
