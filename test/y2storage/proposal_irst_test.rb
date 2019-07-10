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

require_relative "spec_helper"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  using Y2Storage::Refinements::SizeCasts

  include_context "proposal"

  subject(:proposal) { described_class.new(settings: settings) }

  describe "#propose with an IRST partition" do
    let(:scenario) { "irst-windows-linux" }
    let(:resize_info) do
      instance_double("Y2Storage::ResizeInfo", resize_ok?: true, min_size: 300.GiB, max_size: 480.GiB,
        reasons: 0, reason_texts: [])
    end
    let(:original_irst) { fake_devicegraph.find_by_name("/dev/sda1") }
    let(:original_win) { fake_devicegraph.find_by_name("/dev/sda2") }

    before do
      allow_any_instance_of(Y2Storage::Partition).to receive(:detect_resize_info)
        .and_return resize_info

      settings.root_base_size = root_size

      # Let's remove limits and simplify calculations
      settings.root_max_size = Y2Storage::DiskSize.unlimited
      settings.use_snapshots = false
      settings.use_separate_home = false
    end

    context "when it needs to resize windows and delete everything else" do
      let(:root_size) { 100.GiB }

      it "keeps the IRST partition" do
        proposal.propose
        irst = proposal.devices.find_device(original_irst.sid)
        # Is still there and is still IRST
        expect(irst.id.is?(:irst)).to eq true
      end
    end

    context "when it needs to delete all windows and Linux partitions" do
      let(:root_size) { 400.GiB }

      it "keeps the IRST partition if possible" do
        proposal.propose
        irst = proposal.devices.find_device(original_irst.sid)
        # Is still there and is still IRST
        expect(irst.id.is?(:irst)).to eq true
      end
    end

    context "when it really needs to delete all partitions" do
      let(:root_size) { 493.GiB }

      it "deletes the IRST partition" do
        proposal.propose
        expect(proposal.devices.find_device(original_irst.sid)).to be_nil
      end
    end

    context "when other_delete_mode is set to 'all'" do
      # Let's set this to a low value, we are just interested in deletions
      # forced by the settings
      let(:root_size) { 5.GiB }

      before do
        settings.other_delete_mode = :all
        settings.windows_delete_mode = delete_windows
      end

      context "and windows_delete_mode_is set to 'all'" do
        let(:delete_windows) { :all }

        context "and there is a Windows system in the same disk than the IRST partition" do
          it "deletes the IRST partition" do
            proposal.propose
            expect(proposal.devices.find_device(original_irst.sid)).to be_nil
          end
        end

        context "and there is no Windows system in the disk of the IRST partition" do
          before { original_win.filesystem.label = "" }

          it "deletes the IRST partition" do
            proposal.propose
            expect(proposal.devices.find_device(original_irst.sid)).to be_nil
          end
        end
      end

      context "and windows_delete_mode_is set to 'on demand'" do
        let(:delete_windows) { :ondemand }

        context "and there is a Windows system in the same disk than the IRST partition" do
          it "doesn't delete the IRST partition" do
            proposal.propose
            irst = proposal.devices.find_device(original_irst.sid)
            expect(irst.id.is?(:irst)).to eq true
          end
        end

        context "and there is no Windows system in the disk of the IRST partition" do
          before { original_win.filesystem.label = "" }

          it "deletes the IRST partition" do
            proposal.propose
            expect(proposal.devices.find_device(original_irst.sid)).to be_nil
          end
        end
      end

      context "and windows_delete_mode_is set to 'none'" do
        let(:delete_windows) { :none }

        context "and there is a Windows system in the same disk than the IRST partition" do
          it "doesn't delete the IRST partition" do
            proposal.propose
            irst = proposal.devices.find_device(original_irst.sid)
            expect(irst.id.is?(:irst)).to eq true
          end
        end

        context "and there is no Windows system in the disk of the IRST partition" do
          before { original_win.filesystem.label = "" }

          it "deletes the IRST partition" do
            proposal.propose
            expect(proposal.devices.find_device(original_irst.sid)).to be_nil
          end
        end
      end
    end
  end
end
