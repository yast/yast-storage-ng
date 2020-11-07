#!/usr/bin/env rspec

# Copyright (c) [2020] SUSE LLC
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

require_relative "../../test_helper"
require_relative "help_fields_examples"

require "y2partitioner/widgets/description_section/btrfs_subvolume"

describe Y2Partitioner::Widgets::DescriptionSection::BtrfsSubvolume do
  before do
    devicegraph_stub(scenario)
  end

  subject { described_class.new(subvolume) }

  let(:subvolume) { device.filesystem.btrfs_subvolumes.find { |s| s.path == "@/home" } }

  let(:device) { current_graph.find_by_name(device_name) }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:scenario) { "mixed_disks_btrfs" }

  let(:device_name) { "/dev/sda2" }

  describe "#value" do
    it "includes a section title" do
      expect(subject.value).to match(/<h3>.*<\/h3>/)
    end

    it "includes a list of entries" do
      expect(subject.value).to match(/<ul>.*<\/ul>/)
    end

    it "includes an entry about the subvolume path" do
      expect(subject.value).to match(/Path:/)
    end

    it "includes an entry about the mount point" do
      expect(subject.value).to match(/Mount Point:/)
    end

    it "includes an entry about the mounted information" do
      expect(subject.value).to match(/Mounted:/)
    end

    it "includes an entry about the noCoW property" do
      expect(subject.value).to match(/noCoW:/)
    end
  end
end
