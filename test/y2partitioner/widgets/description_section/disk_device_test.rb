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

require "y2partitioner/widgets/description_section/disk_device"

describe Y2Partitioner::Widgets::DescriptionSection::DiskDevice do
  before { devicegraph_stub("mixed_disks") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name("/dev/sda") }

  subject { described_class.new(device) }

  describe "#value" do
    it "includes a section title" do
      expect(subject.value).to match(/<h3>.*<\/h3>/)
    end

    it "includes a list of entries" do
      expect(subject.value).to match(/<ul>.*<\/ul>/)
    end

    it "includes an entry about the device vendor" do
      expect(subject.value).to match(/Vendor:/)
    end

    it "includes an entry about the device model" do
      expect(subject.value).to match(/Model:/)
    end

    it "includes an entry about the bus" do
      expect(subject.value).to match(/Bus:/)
    end

    it "includes an entry about the number of sectors" do
      expect(subject.value).to match(/Sectors:/)
    end

    it "includes an entry about the sector size" do
      expect(subject.value).to match(/Sector Size:/)
    end

    it "includes an entry about the type of partition table" do
      expect(subject.value).to match(/Partition Table:/)
    end
  end

  describe "#help_fields" do
    it "returns a list of symbols" do
      expect(subject.help_fields).to all(be_a(Symbol))
    end

    it "includes a help field for the vendor" do
      expect(subject.help_fields).to include(:vendor)
    end

    it "includes a help field for the model" do
      expect(subject.help_fields).to include(:model)
    end

    it "includes a help field for the bus" do
      expect(subject.help_fields).to include(:bus)
    end

    it "includes a help field for the number of sectors" do
      expect(subject.help_fields).to include(:sectors)
    end

    it "includes a help field for the sector size" do
      expect(subject.help_fields).to include(:sector_size)
    end

    it "includes a help field for the type of partition table" do
      expect(subject.help_fields).to include(:disk_label)
    end
  end
end
