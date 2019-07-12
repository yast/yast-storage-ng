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

require_relative "spec_helper"
require "storage"
require "y2storage"
require_relative "#{TEST_PATH}/support/proposal_examples"
require_relative "#{TEST_PATH}/support/proposal_context"

describe Y2Storage::GuidedProposal do
  describe "#propose with #allocate_volume_mode set to :device" do
    include_context "proposal"

    subject(:proposal) { described_class.new(settings: settings) }
    let(:architecture) { :x86 }
    let(:settings_format) { :ng }
    let(:control_file) { "separate_vgs.xml" }
    let(:scenario) { "empty_disks" }
    let(:vol_sets) { settings.volumes_sets }
    before { settings.separate_vgs = separate_vgs }

    let(:mounted_devices) do
      Y2Storage::MountPoint.all(proposal.devices).map { |i| i.filesystem.blk_devices.first }
    end

    context "when ProposalSettings#lvm is set to false" do
      let(:lvm) { false }

      context "and ProposalSettings#separate_vgs is set to false" do
        let(:separate_vgs) { false }

        context "and all volumes must be located in the same disk" do
          before { vol_sets.each { |vol| vol.device = "/dev/sdb" } }
          let(:expected_scenario) { "volumes-one_disk" }

          include_examples "proposed layout"
        end

        context "and the volumes are assigned to different disks" do
          let(:expected_scenario) { "volumes-three_disks" }

          before do
            vol_sets.each do |set|
              set.device =
                case set.volumes.first.mount_point
                when "/"
                  "/dev/sda"
                when "swap"
                  "/dev/sdc"
                else
                  "/dev/sdb"
                end
            end
          end

          include_examples "proposed layout"
        end
      end
    end

    context "when ProposalSettings#lvm is set to true" do
      let(:lvm) { true }

      context "and ProposalSettings#separate_vgs is set to true" do
        let(:separate_vgs) { true }

        context "and all volumes must be located in the same disk" do
          let(:expected_scenario) { "volumes-one_disk-separate" }

          before { vol_sets.each { |vol| vol.device = "/dev/sda" } }

          include_examples "proposed layout"
        end

        context "and the volumes are assigned to different disks" do
          let(:expected_scenario) { "volumes-three_disks-separate" }

          before do
            vol_sets.each do |set|
              set.device =
                case set.volumes.first.mount_point
                when "/var/spacewalk"
                  "/dev/sda"
                when "/srv"
                  "/dev/sdc"
                else
                  "/dev/sdb"
                end
            end
          end

          include_examples "proposed layout"
        end
      end

      context "but ProposalSettings#separate_vgs is set to false" do
        let(:separate_vgs) { false }

        before do
          vol_sets.each { |vol| vol.device = disk }
        end

        context "and all volumes must be located in the first disk" do
          let(:disk) { "/dev/sda" }
          let(:expected_scenario) { "volumes-first_disk" }

          include_examples "proposed layout"
        end

        context "and all volumes must be located in the first disk" do
          let(:disk) { "/dev/sdc" }
          let(:expected_scenario) { "volumes-last_disk" }

          include_examples "proposed layout"
        end
      end
    end
  end
end
