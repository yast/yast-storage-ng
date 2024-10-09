#!/usr/bin/env rspec
# Copyright (c) [2024] SUSE LLC
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
require "y2storage"

describe Y2Storage::Proposal::SpaceMaker do
  # Partition from fake_devicegraph, fetched by name
  def probed_partition(name)
    fake_devicegraph.partitions.detect { |p| p.name == name }
  end

  before do
    fake_scenario(scenario)
  end

  let(:space_settings) do
    Y2Storage::ProposalSpaceSettings.new.tap do |settings|
      settings.strategy = :bigger_resize
      settings.actions = settings_actions
    end
  end
  let(:settings_actions) { [] }
  let(:analyzer) { Y2Storage::DiskAnalyzer.new(fake_devicegraph) }
  let(:resize) { Y2Storage::SpaceActions::Resize }

  subject(:maker) { described_class.new(analyzer, space_settings) }

  describe "#provide_space" do
    using Y2Storage::Refinements::SizeCasts

    context "if some LVM physical volumes are needed and resizing a partition is possible" do
      let(:scenario) { "space_22_extended" }

      let(:vg) do
        planned_vg(
          volume_group_name: "system", pvs_candidate_devices: ["/dev/sda"],
          lvs: volumes, size_strategy: :use_needed
        )
      end
      let(:volumes) do
        [planned_lv(mount_point: "/1", type: :ext4, logical_volume_name: "one", min: 50.GiB)]
      end

      let(:settings_actions) { [resize.new("/dev/sda1")] }
      let(:resize_info) do
        instance_double("ResizeInfo", resize_ok?: true, min_size: 10.GiB, max_size: 800.GiB)
      end

      before do
        allow_any_instance_of(Y2Storage::Partition)
          .to receive(:detect_resize_info).and_return(resize_info)
      end

      it "shrinks the partition by a sensible size" do
        result = maker.provide_space(fake_devicegraph, volume_groups: [vg])
        expect(result[:devicegraph].partitions).to include(
          # 5 MiB due to several adjustments (LVM, logical partitions, etc.) But the result is
          # just enough to fit the LVM without reclaiming any space that is actually not needed.
          an_object_having_attributes(filesystem_label: "windows", size: 50.GiB - 5.MiB)
        )
      end
    end
  end
end
