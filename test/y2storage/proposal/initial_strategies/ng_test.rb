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

describe Y2Storage::Proposal::InitialStrategies::Ng do
  using Y2Storage::Refinements::SizeCasts

  def volume_settings(settings, mount_point)
    settings.volumes.find { |v| v.mount_point == mount_point }
  end

  include_context "proposal"

  let(:scenario) { "empty_hard_disk_gpt_25GiB" }

  let(:settings_format) { :ng }

  let(:control_file_content) do
    {
      "partitioning" => {
        "proposal" => {
          "lvm" => lvm
        },
        "volumes"  => volumes
      }
    }
  end

  let(:lvm) { nil }

  let(:volumes) { nil }

  let(:root_volume) do
    {
      "proposed"                   => true,
      "proposed_configurable"      => false,
      "mount_point"                => "/",
      "fs_type"                    => "btrfs",
      "desired_size"               => root_desired_size.to_s,
      "min_size"                   => root_min_size.to_s,
      "max_size"                   => root_max_size.to_s,
      "weight"                     => 100,
      "adjust_by_ram"              => true,
      "adjust_by_ram_configurable" => true,
      "snapshots"                  => true,
      "snapshots_configurable"     => true,
      "snapshots_size"             => root_snapshots_size.to_s,
      "disable_order"              => nil
    }
  end

  let(:home_volume) do
    {
      "proposed"                   => true,
      "proposed_configurable"      => true,
      "mount_point"                => "/home",
      "fs_type"                    => "btrfs",
      "desired_size"               => home_desired_size.to_s,
      "min_size"                   => home_min_size.to_s,
      "max_size"                   => home_max_size.to_s,
      "weight"                     => 100,
      "adjust_by_ram"              => true,
      "adjust_by_ram_configurable" => true,
      "snapshots"                  => true,
      "snapshots_configurable"     => true,
      "snapshots_size"             => home_snapshots_size.to_s,
      "disable_order"              => home_disable_order
    }
  end

  let(:swap_volume) do
    {
      "proposed"                   => true,
      "proposed_configurable"      => true,
      "mount_point"                => "swap",
      "fs_type"                    => "swap",
      "desired_size"               => swap_desired_size.to_s,
      "min_size"                   => swap_min_size.to_s,
      "max_size"                   => swap_max_size.to_s,
      "weight"                     => 100,
      "adjust_by_ram"              => true,
      "adjust_by_ram_configurable" => true,
      "disable_order"              => swap_disable_order
    }
  end

  subject { described_class.new }

  describe "#initial_proposal" do
    let(:proposal) { subject.initial_proposal(settings: settings) }

    let(:root_settings) { volume_settings(proposal.settings, "/") }
    let(:home_settings) { volume_settings(proposal.settings, "/home") }
    let(:swap_settings) { volume_settings(proposal.settings, "swap") }

    let(:lvm) { false }

    context "when settings are not passed" do
      let(:settings) { nil }

      it "creates initial proposal settings based on the product (control.xml)" do
        expect(Y2Storage::ProposalSettings).to receive(:new_for_current_product)
          .and_call_original
        proposal
      end
    end

    context "when it is possible to create a proposal using current settings" do
      let(:volumes) { [root_volume] }

      let(:root_desired_size) { 10.GiB }
      let(:root_min_size) { 5.GiB }
      let(:root_max_size) { Y2Storage::DiskSize.unlimited }
      let(:root_snapshots_size) { 5.GiB }

      it "makes a valid proposal without changing settings" do
        expect(proposal.failed?).to be(false)

        expect(root_settings.adjust_by_ram?).to be(true)
        expect(root_settings.snapshots?).to be(true)
        expect(root_settings.proposed?).to be(true)
      end
    end

    context "when it is not possible to create a proposal using adjust_by_ram" do
      let(:volumes) { [root_volume, swap_volume] }

      let(:root_desired_size) { 20.GiB }
      let(:root_min_size) { 15.GiB }
      let(:root_max_size) { Y2Storage::DiskSize.unlimited }
      let(:root_snapshots_size) { 5.GiB }

      let(:swap_desired_size) { 2.GiB }
      let(:swap_min_size) { 1.GiB }
      let(:swap_max_size) { 10.GiB }
      let(:swap_disable_order) { 1 }

      it "makes a valid proposal only deactivating adjust_by_ram" do
        expect(proposal.failed?).to be(false)

        expect(root_settings.adjust_by_ram?).to be(true)
        expect(root_settings.snapshots?).to be(true)
        expect(root_settings.proposed?).to be(true)

        expect(swap_settings.adjust_by_ram?).to be(false)
        expect(swap_settings.proposed?).to be(true)
      end
    end

    context "when it is not possible to create a proposal using snapshots" do
      let(:volumes) { [root_volume] }

      let(:root_desired_size) { 25.GiB }
      let(:root_min_size) { 22.GiB }
      let(:root_max_size) { Y2Storage::DiskSize.unlimited }
      let(:root_snapshots_size) { 5.GiB }

      it "makes a valid proposal deactivating snapshots" do
        expect(proposal.failed?).to be(false)

        expect(root_settings.adjust_by_ram?).to be(false)
        expect(root_settings.snapshots?).to be(false)
        expect(root_settings.proposed?).to be(true)
      end
    end

    context "when it is not possible to create a proposal using a volume" do
      let(:volumes) { [root_volume, home_volume] }

      let(:root_desired_size) { 20.GiB }
      let(:root_min_size) { 15.GiB }
      let(:root_max_size) { Y2Storage::DiskSize.unlimited }
      let(:root_snapshots_size) { 5.GiB }

      let(:home_desired_size) { 20.GiB }
      let(:home_min_size) { 15.GiB }
      let(:home_max_size) { 50.GiB }
      let(:home_snapshots_size) { 5.GiB }
      let(:home_disable_order) { 1 }

      it "makes a valid proposal deactivating the volume" do
        expect(proposal.failed?).to be(false)

        expect(root_settings.adjust_by_ram?).to be(true)
        expect(root_settings.snapshots?).to be(true)
        expect(root_settings.proposed?).to be(true)

        expect(home_settings.adjust_by_ram?).to be(false)
        expect(home_settings.snapshots?).to be(false)
        expect(home_settings.proposed?).to be(false)
      end
    end

    context "when it is not possible to create a proposal using all volumes" do
      let(:volumes) { [root_volume, swap_volume, home_volume] }

      let(:root_desired_size) { 20.GiB }
      let(:root_min_size) { 15.GiB }
      let(:root_max_size) { Y2Storage::DiskSize.unlimited }
      let(:root_snapshots_size) { 5.GiB }

      let(:swap_desired_size) { 2.GiB }
      let(:swap_min_size) { 1.GiB }
      let(:swap_max_size) { 2.GiB }

      let(:home_desired_size) { 20.GiB }
      let(:home_min_size) { 15.GiB }
      let(:home_max_size) { 50.GiB }
      let(:home_snapshots_size) { 5.GiB }

      context "and disable_order implies to deactivate all possible volumes" do
        let(:swap_disable_order) { 1 }
        let(:home_disable_order) { 2 }

        it "deactivates all possible volumes" do
          expect(root_settings.proposed?).to be(true)
          expect(swap_settings.proposed?).to be(false)
          expect(home_settings.proposed?).to be(false)
        end
      end

      context "and disable_order implies to deactivate big volumes first" do
        let(:swap_disable_order) { 2 }
        let(:home_disable_order) { 1 }

        it "deactivates only necessary volumes" do
          expect(root_settings.proposed?).to be(true)
          expect(swap_settings.proposed?).to be(true)
          expect(home_settings.proposed?).to be(false)
        end
      end
    end

    context "when it is not possible to create a proposal" do
      let(:volumes) { [root_volume, swap_volume, home_volume] }

      let(:root_desired_size) { 30.GiB }
      let(:root_min_size) { 25.GiB }
      let(:root_max_size) { Y2Storage::DiskSize.unlimited }
      let(:root_snapshots_size) { 5.GiB }

      let(:swap_desired_size) { 2.GiB }
      let(:swap_min_size) { 2.GiB }
      let(:swap_max_size) { 2.GiB }
      let(:swap_disable_order) { 1 }

      let(:home_desired_size) { 20.GiB }
      let(:home_min_size) { 15.GiB }
      let(:home_max_size) { 50.GiB }
      let(:home_snapshots_size) { 5.GiB }
      let(:home_disable_order) { 2 }

      it "disables all possible volumes" do
        expect(root_settings.proposed?).to be(true)
        expect(swap_settings.proposed?).to be(false)
        expect(home_settings.proposed?).to be(false)
      end

      it "does not make a valid proposal" do
        expect(proposal.failed?).to be(true)
      end
    end
  end
end
