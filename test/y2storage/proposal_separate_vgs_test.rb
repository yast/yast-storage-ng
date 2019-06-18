#!/usr/bin/env rspec
# encoding: utf-8

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
  describe "#propose" do
    include_context "proposal"

    subject(:proposal) { described_class.new(settings: settings) }
    let(:architecture) { :x86 }
    let(:settings_format) { :ng }
    let(:control_file) { "separate_vgs.xml" }
    let(:scenario) { "empty_disks" }
    before { settings.separate_vgs = separate_vgs }

    let(:mounted_devices) do
      Y2Storage::MountPoint.all(proposal.devices).map { |i| i.filesystem.blk_devices.first }
    end

    context "when ProposalSettings#lvm is set to true" do
      let(:lvm) { true }

      context "and ProposalSettings#separate_vgs is set to true" do
        let(:separate_vgs) { true }

        it "proposes an LVM VG for every separate volume and another for system volumes" do
          proposal.propose
          vgs = proposal.devices.lvm_vgs

          expect(vgs.map(&:vg_name)).to contain_exactly("system", "spacewalk", "srv_vg")
          is_lv = mounted_devices.map { |i| i.is?(:lvm_lv) }
          expect(is_lv).to all(eq(true))
        end
      end

      context "but ProposalSettings#separate_vgs is set to false" do
        let(:separate_vgs) { false }

        it "proposes only the system LVM VG containing all logical volumes" do
          proposal.propose
          vgs = proposal.devices.lvm_vgs

          expect(vgs.size).to eq 1
          expect(vgs.first.vg_name).to eq "system"
          is_lv = mounted_devices.map { |i| i.is?(:lvm_lv) }
          expect(is_lv).to all(eq(true))
        end
      end
    end

    context "when ProposalSettings#lvm is set to false" do
      let(:lvm) { false }

      context "but ProposalSettings#separate_vgs is set to true" do
        let(:separate_vgs) { true }

        it "proposes some system partitions plus an LVM VG for every separate volume" do
          proposal.propose
          vgs = proposal.devices.lvm_vgs

          expect(vgs.map(&:vg_name)).to contain_exactly("spacewalk", "srv_vg")
          lvs = mounted_devices.select { |i| i.is?(:lvm_lv) }
          partitions = mounted_devices.select { |i| i.is?(:partition) }
          expect(lvs.size).to eq 2
          expect(partitions.size).to eq 2
        end
      end

      context "and ProposalSettings#separate_vgs is set to false" do
        let(:separate_vgs) { false }

        it "proposes everything as partitions with no LVM VGs" do
          proposal.propose
          vgs = proposal.devices.lvm_vgs

          expect(vgs).to be_empty
          is_partition = mounted_devices.map { |i| i.is?(:partition) }
          expect(is_partition).to all(eq(true))
        end
      end
    end
  end
end
