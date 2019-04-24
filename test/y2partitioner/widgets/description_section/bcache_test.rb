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

require "y2partitioner/widgets/description_section/bcache"

describe Y2Partitioner::Widgets::DescriptionSection::Bcache do
  before { devicegraph_stub("bcache1.xml") }

  let(:current_graph) { Y2Partitioner::DeviceGraphs.instance.current }

  let(:bcache) { current_graph.find_by_name("/dev/bcache0") }

  subject { described_class.new(bcache) }

  describe "#value" do
    it "includes a section title" do
      expect(subject.value).to match(/<h3>.*<\/h3>/)
    end

    it "includes a list of entries" do
      expect(subject.value).to match(/<ul>.*<\/ul>/)
    end

    it "includes an entry about the backing device" do
      expect(subject.value).to match(/Backing Device:/)
    end

    it "includes an entry about the caching UUID" do
      expect(subject.value).to match(/Caching UUID:/)
    end

    it "includes an entry about the caching device" do
      expect(subject.value).to match(/Caching Device:/)
    end

    it "includes an entry about the cache mode" do
      expect(subject.value).to match(/Cache Mode:/)
    end
  end

  describe "#help_fields" do
    it "returns a list of symbols" do
      expect(subject.help_fields).to all(be_a(Symbol))
    end

    it "includes a help field for the backing device" do
      expect(subject.help_fields).to include(:backing_device)
    end

    it "includes a help field for the caching uuid" do
      expect(subject.help_fields).to include(:caching_uuid)
    end

    it "includes a help field for the caching device" do
      expect(subject.help_fields).to include(:caching_device)
    end

    it "includes a help field for the cache mode" do
      expect(subject.help_fields).to include(:cache_mod)
    end
  end
end
