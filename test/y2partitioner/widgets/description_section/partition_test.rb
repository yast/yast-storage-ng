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

require_relative "../../test_helper"
require_relative "help_fields_examples"

require "y2partitioner/widgets/description_section/partition"

describe Y2Partitioner::Widgets::DescriptionSection::Partition do
  before { devicegraph_stub("mixed_disks") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:device) { current_graph.find_by_name("/dev/sda2") }

  subject { described_class.new(device) }

  describe "#value" do
    it "includes a section title" do
      expect(subject.value).to match(/<h3>.*<\/h3>/)
    end

    it "includes a list of entries" do
      expect(subject.value).to match(/<ul>.*<\/ul>/)
    end

    it "includes an entry about the device name" do
      expect(subject.value).to match(/Device:/)
    end

    it "includes an entry about the device size" do
      expect(subject.value).to match(/Size:/)
    end

    it "includes an entry about the encryption" do
      expect(subject.value).to match(/Encrypted:/)
    end

    it "includes an entry about the udev by_path values" do
      expect(subject.value).to match(/Device Path:/)
    end

    it "includes an entry about the udev by_id values" do
      expect(subject.value).to match(/Device ID:/)
    end

    it "includes an entry about the partition ID" do
      expect(subject.value).to match(/Partition ID:/)
    end
  end

  describe "#help_fields" do
    let(:excluded_help_fields) { [] }

    include_examples "help fields"
  end
end
