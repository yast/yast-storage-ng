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

require_relative "spec_helper"
require_relative "support/proposal_examples"
require_relative "support/proposal_context"

describe Y2Storage::Proposal do
  include_context "proposal"

  describe "#propose (with pre-existing swap partitions)" do
    using Y2Storage::Refinements::SizeCasts
    using Y2Storage::Refinements::DevicegraphLists

    before do
      allow(Y2Storage::Proposal::VolumesGenerator).to receive(:new).and_return volumes_generator
      settings.root_device = "/dev/sda"
    end

    let(:scenario) { "swaps" }
    let(:windows_partitions) { {} }
    let(:volumes_generator) do
      base_volumes = [
        planned_vol(mount_point: "/", type: :ext4, desired: 500.MiB, max: 500.MiB)
      ]
      all_volumes = [
        planned_vol(mount_point: "/", type: :ext4, desired: 500.MiB, max: 500.MiB),
        planned_vol(mount_point: "swap", reuse: "/dev/sda3"),
        planned_vol(mount_point: "swap", type: :swap, desired: 500.MiB, max: 500.MiB),
        planned_vol(mount_point: "swap", type: :swap, desired: 500.MiB, max: 500.MiB),
        planned_vol(mount_point: "swap", type: :swap, desired: 500.MiB, max: 500.MiB)
      ]
      instance_double(
        "Y2Storage::Proposal::VolumesGenerator",
        base_volumes: Y2Storage::PlannedVolumesList.new(base_volumes),
        all_volumes:  Y2Storage::PlannedVolumesList.new(all_volumes)
      )
    end

    it "reuses suitable swap partitions" do
      proposal.propose
      sda3 = proposal.devices.partitions.with(name: "/dev/sda3").first
      expect(sda3).to match_fields(
        mountpoint: "swap",
        uuid:       "33333333-3333-3333-3333-33333333",
        label:      "swap3",
        size:       (1.GiB - 1.MiB).to_i
      )
    end

    it "reuses UUID and label of deleted swap partitions" do
      proposal.propose
      sda2 = proposal.devices.partitions.with(name: "/dev/sda2").first
      expect(sda2).to match_fields(
        mountpoint: "swap",
        uuid:       "11111111-1111-1111-1111-11111111",
        label:      "swap1",
        size:       500.MiB.to_i
      )
      sda5 = proposal.devices.partitions.with(name: "/dev/sda5").first
      expect(sda5).to match_fields(
        mountpoint: "swap",
        uuid:       "22222222-2222-2222-2222-22222222",
        label:      "swap2",
        size:       500.MiB.to_i
      )
    end

    it "does not enforce any particular UUID or label for additional swaps" do
      proposal.propose
      sda6 = proposal.devices.partitions.with(name: "/dev/sda6").first
      expect(sda6).to match_fields(mountpoint: "swap", uuid: "", label: "")
    end
  end
end
