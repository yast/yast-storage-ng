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

require_relative "../../test_helper"

require "y2partitioner/widgets/description_section/md"

describe Y2Partitioner::Widgets::DescriptionSection::Md do
  before { devicegraph_stub("md_raid") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name("/dev/md/md0") }

  subject { described_class.new(device) }

  describe "#value" do
    it "includes a section title" do
      expect(subject.value).to match(/<h3>.*<\/h3>/)
    end

    it "includes a list of entries" do
      expect(subject.value).to match(/<ul>.*<\/ul>/)
    end

    it "includes an entry about the MD status" do
      expect(subject.value).to match(/Active:/)
    end

    it "includes an entry about the RAID type" do
      expect(subject.value).to match(/RAID Type:/)
    end

    it "includes an entry about the chunk size" do
      expect(subject.value).to match(/Chunk Size:/)
    end
    it "includes an entry about the parity algorithm" do
      expect(subject.value).to match(/Parity Algorithm:/)
    end
    it "includes an entry about the partition table type" do
      expect(subject.value).to match(/Partition Table:/)
    end
  end

  describe "#help_fields" do
    it "returns a list of symbols" do
      expect(subject.help_fields).to all(be_a(Symbol))
    end

    it "includes a help field for raid type" do
      expect(subject.help_fields).to include(:raid_type)
    end

    it "includes a help field for the chunk size" do
      expect(subject.help_fields).to include(:chunk_size)
    end

    it "includes a help field for the parity algorithm" do
      expect(subject.help_fields).to include(:parity_algorithm)
    end
    it "includes a help field for the partition table type" do
      expect(subject.help_fields).to include(:disk_label)
    end
  end
end
